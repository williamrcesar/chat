module Admin
  class ConversationsController < BaseController
    before_action :set_conversation, only: %i[ show destroy mode send_message ]
    helper_method :allowed_impersonate_participant?

    def index
      scope_type  = params[:scope].presence || default_scope_type
      time_window = (params[:minutes] || 1440).to_i.minutes

      base_scope =
        if scope_type == "company"
          company = find_company_for_current_user
          conversations_for_company(company)
        else
          conversations_globally_active(time_window)
        end

      @pagy, @conversations = pagy(
        base_scope.includes(:participants, :messages, :conversation_assignment, :company)
                  .order(updated_at: :desc),
        limit: 25
      )
    end

    def show
      authorize([:admin, @conversation])
      @admin_mode = (params[:mode].presence || "monitor").in?(%w[monitor impersonate]) ? params[:mode] : "monitor"
      @impersonate_user_id = session[:admin_impersonate_user_id] if session[:admin_impersonate_conversation_id].to_i == @conversation.id
      @viewer_user = (@admin_mode == "impersonate" && @impersonate_user_id.present?) ? User.find_by(id: @impersonate_user_id) : nil

      # When the admin is not a participant (monitor mode), keep left/right alignment meaningful:
      # - company-side users (owner + attendants) on the right
      # - external users on the left
      @right_side_sender_ids =
        if @viewer_user
          [ @viewer_user.id ]
        elsif @conversation.is_company_conversation? && @conversation.company_id.present?
          attendant_ids = CompanyAttendant.where(company_id: @conversation.company_id).pluck(:user_id)
          owner_id = @conversation.company&.owner_id
          (attendant_ids + [ owner_id ]).compact.uniq
        else
          []
        end

      @pagy, @messages = pagy(
        @conversation.messages
                     .visible
                     .includes(:sender, :reply_to, :reactions, attachment_attachment: :blob)
                     .order(created_at: :desc),
        limit: 40
      )
      @messages = @messages.reverse
      @participants = @conversation.participants.includes(:user)
      @assignment = @conversation.conversation_assignment
      @companies_for_scope = current_user.role_admin? ? Company.order(:name) : []
      @conversations_sidebar = admin_conversation_scope.includes(:participants, :users, :conversation_assignment, :company).limit(30)
    end

    def destroy
      authorize([:admin, @conversation])
      @conversation.destroy
      redirect_to admin_conversations_path, notice: "Conversa removida."
    end

    def mode
      authorize([:admin, @conversation])
      mode_val = params[:mode].presence
      if mode_val == "impersonate"
        user_id = params[:impersonate_user_id].presence
        if user_id.present? && allowed_impersonate_user_id?(user_id)
          session[:admin_impersonate_conversation_id] = @conversation.id
          session[:admin_impersonate_user_id] = user_id.to_i
        end
      else
        session.delete(:admin_impersonate_conversation_id)
        session.delete(:admin_impersonate_user_id)
      end
      redirect_to admin_conversation_path(@conversation, mode: mode_val || "monitor")
    end

    def send_message
      authorize([:admin, @conversation])
      unless session[:admin_impersonate_conversation_id].to_i == @conversation.id && session[:admin_impersonate_user_id].present?
        return redirect_to admin_conversation_path(@conversation, mode: "monitor"), alert: "Selecione um usuário para impersonar antes de enviar."
      end

      impersonate_user_id = session[:admin_impersonate_user_id].to_i
      unless allowed_impersonate_user_id?(impersonate_user_id.to_s)
        return redirect_to admin_conversation_path(@conversation, mode: "impersonate"), alert: "Usuário não autorizado para impersonar."
      end

      content = params.dig(:message, :content).to_s.strip
      if content.blank?
        return redirect_to admin_conversation_path(@conversation, mode: "impersonate"), alert: "Digite uma mensagem."
      end

      msg = @conversation.messages.build(
        content: content,
        sender_id: impersonate_user_id,
        message_type: :text
      )
      msg.metadata = (msg.metadata || {}).merge(
        "impersonated" => true,
        "admin_id" => current_user.id
      )
      msg.save!
      msg.mark_sent!
      broadcast_new_message_to_recipients(msg)
      @conversation.touch
      redirect_to admin_conversation_path(@conversation, mode: "impersonate"), notice: "Mensagem enviada como #{User.find(impersonate_user_id).display_name}."
    end

    private

    def set_conversation
      @conversation = Conversation.find(params[:id])
    end

    def admin_conversation_scope
      scope_type = params[:scope].presence || default_scope_type
      base = if scope_type == "company"
        company = find_company_for_current_user
        company ? Conversation.with_open_assignment_for_company(company).distinct : Conversation.none
      else
        Conversation.globally_active_since(((params[:minutes] || 1440).to_i).minutes.ago)
      end
      base.reorder(updated_at: :desc)
    end

    def default_scope_type
      current_user.role_admin? ? "global" : "company"
    end

    def find_company_for_current_user
      if current_user.role_admin?
        return Company.find(params[:company_id]) if params[:company_id].present?
        return nil
      end

      supervisor_attendant = current_user.company_attendants.supervisors.first
      supervisor_attendant&.company
    end

    def conversations_for_company(company)
      return Conversation.none unless company

      scope = Conversation.with_open_assignment_for_company(company)

      if params[:status].present?
        scope = scope.joins(:conversation_assignment)
                     .where(conversation_assignments: { status: params[:status] })
      end

      if params[:attendant_id].present?
        scope = scope.joins(:conversation_assignment)
                     .where(conversation_assignments: { company_attendant_id: params[:attendant_id] })
      end

      scope
    end

    def conversations_globally_active(time_window)
      scope = Conversation.globally_active_since(time_window.ago)

      if params[:search].present?
        term = "%#{params[:search].strip.downcase}%"
        scope = scope.joins(:users)
                     .where("LOWER(users.display_name) LIKE ? OR LOWER(users.nickname) LIKE ?", term, term)
                     .distinct
      end

      scope
    end

    def allowed_impersonate_participant?(participant)
      allowed_impersonate_user_id?(participant.user_id.to_s)
    end

    def allowed_impersonate_user_id?(user_id_str)
      user_id = user_id_str.to_i
      return false if user_id.zero?
      return false unless @conversation.participants.exists?(user_id: user_id)

      if current_user.role_admin?
        true
      else
        # Supervisor: only attendants of the same company
        company_ids = current_user.company_attendants.supervisors.pluck(:company_id)
        return false unless @conversation.conversation_assignment&.company_id.in?(company_ids)
        attendant_user_ids = CompanyAttendant.where(company_id: @conversation.conversation_assignment.company_id).pluck(:user_id)
        user_id.in?(attendant_user_ids) || user_id == @conversation.company&.owner_id
      end
    end

    def broadcast_new_message_to_recipients(message)
      message.attachment.blob if message.attachment.attached?
      conversation = message.conversation
      sender_id = message.sender_id
      conversation.participants.includes(:user).each do |participant|
        next if participant.user_id == sender_id
        html = ApplicationController.renderer.render(
          partial: "messages/message",
          locals: { message: message, current_user: participant.user }
        )
        ChatChannel.broadcast_to([ conversation, participant.user ], { type: "new_message", message: html, message_id: message.id })
      end
      # Broadcast to admin viewers (read-only stream)
      right_side_sender_ids = []
      if conversation.is_company_conversation? && conversation.company_id.present?
        attendant_ids = CompanyAttendant.where(company_id: conversation.company_id).pluck(:user_id)
        owner_id = conversation.company&.owner_id
        right_side_sender_ids = (attendant_ids + [ owner_id ]).compact.uniq
      end
      html_admin = ApplicationController.renderer.render(
        partial: "messages/message",
        locals: { message: message, current_user: nil, right_side_sender_ids: right_side_sender_ids }
      )
      ActionCable.server.broadcast("admin_conversation_#{conversation.id}", { type: "new_message", message: html_admin, message_id: message.id })
    end
  end
end
