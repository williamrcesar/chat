class ConversationsController < ApplicationController
  before_action :set_conversation, only: %i[ show add_participant remove_participant archive unarchive toggle_pin ]

  def index
    # Ordenar: fixadas primeiro (máx 10), depois por última atividade (última mensagem enviada/recebida = conversations.updated_at)
    ordered_ids = Conversation.joins(:participants)
      .where(participants: { user_id: current_user.id, archived: false })
      .order("participants.pinned DESC, conversations.updated_at DESC")
      .pluck(:id).uniq
    @conversations = Conversation.where(id: ordered_ids).includes(:users, :messages, :company, :participants)
    @conversations = @conversations.sort_by { |c| ordered_ids.index(c.id) }

    archived_ids = current_user.conversations.archived(current_user).pluck(:id).uniq
    @archived_conversations = Conversation.where(id: archived_ids).includes(:users, :messages, :company, :participants).recent
    @users = User.where.not(id: current_user.id).order(:display_name)
    @pending_requests_count = current_user.pending_contact_requests_count
  end

  def show
    authorize @conversation
    # Evitar cache do navegador ao abrir conversa (sempre mensagens e status atualizados)
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    @pagy, @messages = pagy(
      @conversation.messages
                   .visible
                   .includes(:sender, :reply_to, :reactions, :read_receipts, conversation: { participants: :user }, attachment_attachment: :blob)
                   .order(created_at: :desc),
      limit: 40
    )
    # Reverse so oldest appears at top, newest at bottom
    @messages = @messages.reverse
    @participant = @conversation.participants.find_by(user: current_user)
    @had_unread = @conversation.unread_count_for(current_user)
    # Primeira mensagem não lida (para mostrar divisor "Mensagens não lidas" no estilo WhatsApp)
    last_read = @participant&.last_read_at || Time.at(0)
    first_unread = @messages.find { |m| m.created_at > last_read && m.sender_id != current_user.id }
    @first_unread_message_id = first_unread&.id
    @participant&.mark_read!
    # Quando o destinatário abre a conversa, marcar como "entregue" (2 checks) as mensagens que ainda estavam só "enviadas"
    mark_received_as_delivered_for_current_user
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
    unless participant
      redirect_back fallback_location: root_path
      return
    end
    if participant.pinned?
      participant.update!(pinned: false)
    else
      pinned_count = current_user.participants.where(pinned: true).count
      if pinned_count >= 10
        redirect_back fallback_location: root_path, alert: "Máximo de 10 conversas fixadas."
        return
      end
      participant.update!(pinned: true)
    end
    redirect_back fallback_location: root_path
  end

  private

  def set_conversation
    @conversation = current_user.conversations.find(params[:id])
  end

  def conversation_params
    params.require(:conversation).permit(:name, :description, :conversation_type, :avatar)
  end

  # Mensagens enviadas por outros que o usuário ainda não "recebeu" → marcar como entregue (2 checks para o remetente)
  # perform_now para o remetente ver os 2 checks imediatamente ao abrir a conversa
  def mark_received_as_delivered_for_current_user
    @conversation.messages
      .where.not(sender_id: current_user.id)
      .where(status: :sent)
      .pluck(:id)
      .each do |message_id|
        message = Message.find_by(id: message_id)
        next unless message&.status_sent?

        message.mark_delivered!
        MessageUpdateBroadcastJob.perform_now(message_id)
      end
  end
end
