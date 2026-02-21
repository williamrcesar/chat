class ConversationsController < ApplicationController
  before_action :set_conversation, only: %i[ show add_participant remove_participant archive unarchive toggle_pin ]

  def index
    @conversations = current_user.conversations
                                 .sorted_for(current_user)
                                 .includes(:users, :messages, :company)
                                 .where(participants: { archived: false })
    @archived_conversations = current_user.conversations
                                          .archived(current_user)
                                          .includes(:users, :messages, :company)
                                          .recent
    @users = User.where.not(id: current_user.id).order(:display_name)
    @pending_requests_count = current_user.pending_contact_requests_count
  end

  def show
    authorize @conversation
    @pagy, @messages = pagy(
      @conversation.messages
                   .visible
                   .includes(:sender, :reply_to, :reactions, attachment_attachment: :blob)
                   .order(created_at: :desc),
      items: 40
    )
    # Reverse so oldest appears at top, newest at bottom
    @messages = @messages.reverse
    @participant = @conversation.participants.find_by(user: current_user)
    @participant&.mark_read!
  end

  def create
    if params[:user_id].present?
      other_user = User.find(params[:user_id])

      # If they already have a direct conversation, go straight there
      if current_user.contact_with?(other_user)
        @conversation = Conversation.find_or_create_direct(current_user, other_user)
        redirect_to conversation_path(@conversation)
      else
        # Send a contact request instead of creating a conversation immediately
        existing = ContactRequest.find_by(sender: current_user, receiver: other_user)
        if existing&.status_accepted?
          @conversation = Conversation.find_or_create_direct(current_user, other_user)
          redirect_to conversation_path(@conversation)
        elsif existing
          redirect_to root_path, notice: "Solicitação já enviada, aguardando aprovação."
        else
          ContactRequest.create!(
            sender:       current_user,
            receiver:     other_user,
            preview_type: "text",
            preview_text: "Olá! Gostaria de conversar com você."
          )
          redirect_to root_path, notice: "Solicitação de contato enviada para #{other_user.display_name}."
        end
      end
    else
      @conversation = Conversation.new(conversation_params)
      @conversation.participants.build(user: current_user, role: :admin)
      authorize @conversation
      unless @conversation.save
        redirect_to root_path, alert: "Não foi possível criar o grupo."
        return
      end
      redirect_to conversation_path(@conversation)
    end
  end

  def add_participant
    authorize @conversation
    user = User.find(params[:user_id])
    @conversation.participants.find_or_create_by!(user: user) do |p|
      p.role = :member
    end
    redirect_to conversation_path(@conversation), notice: "#{user.display_name} adicionado(a)."
  end

  def remove_participant
    authorize @conversation
    participant = @conversation.participants.find_by(user_id: params[:user_id])
    participant&.destroy
    redirect_to conversation_path(@conversation), notice: "Participante removido."
  end

  def archive
    participant = @conversation.participants.find_by(user: current_user)
    participant&.archive!
    redirect_to root_path, notice: "Conversa arquivada."
  end

  def unarchive
    participant = @conversation.participants.find_by(user: current_user)
    participant&.unarchive!
    redirect_to root_path, notice: "Conversa desarquivada."
  end

  def toggle_pin
    participant = @conversation.participants.find_by(user: current_user)
    participant&.toggle_pin!
    redirect_back fallback_location: root_path
  end

  private

  def set_conversation
    @conversation = current_user.conversations.find(params[:id])
  end

  def conversation_params
    params.require(:conversation).permit(:name, :description, :conversation_type, :avatar)
  end
end
