class MessagesController < ApplicationController
  before_action :set_conversation
  before_action :set_message, only: %i[ delete_for_everyone ]

  def create
    raw = Array(params.dig(:message, :attachment)).compact_blank
    attachments = raw.select { |a| a.respond_to?(:tempfile) && a.tempfile.present? }
    content = message_params[:content].presence

    if attachments.size > 1
      # Idempotência por client_message_id: se já processamos este envio, não duplicar
      client_message_id = message_params[:client_message_id].presence
      if client_message_id && message_with_client_id_exists?(client_message_id)
        authorize Message.new(conversation: @conversation, sender: current_user)
        respond_to do |format|
          format.turbo_stream { head :no_content }
          format.html { redirect_to conversation_path(@conversation) }
        end
        return
      end

      # Vários anexos: uma mensagem por arquivo (primeira pode ter texto); cada uma com o mesmo client_message_id
      base = message_params.to_h.symbolize_keys.slice(:content, :reply_to_id)
      @messages = attachments.each_with_index.map do |file, i|
        msg = @conversation.messages.build(
          base.merge(content: i.zero? ? content : nil, sender: current_user)
        )
        msg.metadata = (msg.metadata || {}).merge("client_message_id" => client_message_id) if client_message_id.present?
        msg.attachment.attach(file)
        msg.message_type = detect_message_type(file)
        authorize msg
        msg.save! ? msg : nil
      end.compact
      if @messages.any?
        @messages.each do |msg|
          msg.mark_sent!
          mark_delivered_if_recipient_online!(msg)
          broadcast_new_message_to_recipients(msg)
          fetch_link_preview_now(msg)
        end
        @conversation.participants.find_by(user: current_user)&.mark_read!
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to conversation_path(@conversation) }
        end
      else
        redirect_to conversation_path(@conversation), alert: "Não foi possível enviar."
      end
    else
      client_message_id = message_params[:client_message_id].presence
      if client_message_id && message_with_client_id_exists?(client_message_id)
        authorize Message.new(conversation: @conversation, sender: current_user)
        respond_to do |format|
          format.turbo_stream { head :no_content }
          format.html { redirect_to conversation_path(@conversation) }
        end
        return
      end

      # Fallback: mesmo texto, mesmo usuário, mesma conversa, nos últimos 2s = duplicata (evita envios que passaram pelo cliente)
      if attachments.none? && content.present?
        dup = @conversation.messages
          .where(sender_id: current_user.id)
          .where("created_at >= ?", 2.seconds.ago)
          .where("TRIM(COALESCE(content, '')) = ?", content.to_s.strip)
          .order(created_at: :desc)
          .first
        if dup
          authorize Message.new(conversation: @conversation, sender: current_user)
          respond_to do |format|
            format.turbo_stream { head :no_content }
            format.html { redirect_to conversation_path(@conversation) }
          end
          return
        end
      end

      # Um anexo ou só texto (não passar attachment ao build — evita "expected attachable, got []")
      @message = @conversation.messages.build(message_params.except(:attachment, :client_message_id))
      @message.sender = current_user
      @message.metadata = (@message.metadata || {}).merge("client_message_id" => client_message_id) if client_message_id.present?
      if attachments.one?
        @message.attachment.attach(attachments.first)
        @message.message_type = detect_message_type(attachments.first)
      end
      authorize @message
      if @message.save
        @conversation.touch # ordenação da lista: última atividade (envio) já no topo
        @message.mark_sent!
        mark_delivered_if_recipient_online!(@message)
        broadcast_new_message_to_recipients(@message)
        fetch_link_preview_now(@message)
        @conversation.participants.find_by(user: current_user)&.mark_read!
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to conversation_path(@conversation) }
        end
      else
        redirect_to conversation_path(@conversation), alert: "Não foi possível enviar a mensagem."
      end
    end
  end

  def forward
    source = Message.joins(:conversation)
                    .joins("INNER JOIN participants ON participants.conversation_id = conversations.id")
                    .where(participants: { user_id: current_user.id })
                    .find(params[:message_id])

    target_conversation = current_user.conversations.find(params[:target_conversation_id])

    @message = target_conversation.messages.create!(
      sender:          current_user,
      content:         source.content,
      message_type:    source.message_type,
      forwarded_from:  source
    )

    if source.attachment.attached?
      @message.attachment.attach(source.attachment.blob)
    end

    @conversation = target_conversation
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to conversation_path(target_conversation), notice: "Mensagem encaminhada." }
      format.json { render json: { ok: true } }
    end
  end

  def delete_for_everyone
    unless @message.sender == current_user
      return redirect_to conversation_path(@conversation), alert: "Você só pode apagar suas próprias mensagens."
    end
    @message.soft_delete_for_everyone!
    respond_to do |format|
      format.html { redirect_to conversation_path(@conversation), notice: "Mensagem apagada para todos." }
      format.json { head :ok }
    end
  end

  def send_sticker
    @message = @conversation.messages.new(
      sender:       current_user,
      content:      nil,
      message_type: :sticker,
      metadata:     {}
    )

    if params[:sticker_id].present?
      sticker = current_user.stickers.find_by(id: params[:sticker_id])
      return head(:not_found) unless sticker
      @message.attachment.attach(sticker.image.blob)
    elsif params[:sticker_file].present?
      @message.attachment.attach(params[:sticker_file])
    else
      return head(:unprocessable_entity)
    end

    @message.save!

    @conversation.touch
    @message.mark_sent!
    mark_delivered_if_recipient_online!(@message)
    broadcast_new_message_to_recipients(@message)
    @conversation.participants.find_by(user: current_user)&.mark_read!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to conversation_path(@conversation) }
    end
  end

  def from_template
    template = Template.find(params[:template_id])
    rendered_content = template.render_with(params[:variables] || {})
    @message = @conversation.messages.create!(
      sender: current_user,
      content: rendered_content,
      message_type: :template
    )
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to conversation_path(@conversation) }
    end
  end

  def mark_read
    message = @conversation.messages.find(params[:id])
    ReadReceipt.find_or_create_by!(message: message, user: current_user) do |rr|
      rr.read_at = Time.current
    end
    message.advance_to_read_if_receipts_complete!
    head :ok
  end

  def index
    @pagy, messages = pagy(
      @conversation.messages
                   .visible
                   .includes(:sender, :reply_to, :reactions, read_receipts: :user, conversation: { participants: :user }, attachment_attachment: :blob)
                   .order(created_at: :desc),
      limit: 40,
      page: params[:page] || 1
    )
    @messages = messages.reverse
    @has_more  = @pagy.page < @pagy.pages

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.prepend("messages",
            partial: "messages/message_batch",
            locals: { messages: @messages, current_user: current_user }),
          (@has_more ? turbo_stream.replace("load-more-trigger",
            partial: "messages/load_more",
            locals: { conversation: @conversation, next_page: @pagy.page + 1 }) :
            turbo_stream.remove("load-more-trigger"))
        ]
      end
      format.html { redirect_to conversation_path(@conversation) }
    end
  end

  def search
    @query = params[:q].to_s.strip
    @messages = if @query.present?
      @conversation.messages.visible.search_content(@query).includes(:sender).recent
    else
      []
    end
    render partial: "messages/search_results",
           locals: { messages: @messages, conversation: @conversation, query: @query }
  end

  private

  def set_conversation
    @conversation = current_user.conversations.find(params[:conversation_id])
  end

  def set_message
    @message = @conversation.messages.find(params[:id])
  end

  def message_params
    params.require(:message).permit(:content, :reply_to_id, :client_message_id, attachment: [])
  end

  def detect_message_type(file)
    content_type = file.content_type
    case content_type
    when /image/ then :image
    when /audio/ then :audio
    when /video/ then :video
    else :document
    end
  end

  def fetch_link_preview_now(message)
    return unless message.content.to_s.match?(%r{\bhttps?://})
    LinkPreviewJob.perform_later(message.id)
  end

  # Verifica se já existe mensagem(ns) com este client_message_id (mesmo envio = idempotência).
  def message_with_client_id_exists?(client_message_id)
    @conversation.messages
      .where(sender_id: current_user.id)
      .where("metadata->>'client_message_id' = ?", client_message_id)
      .exists?
  end

  # Se algum destinatário está online (app aberto), marcar como entregue de imediato → 2 checks cinzas.
  def mark_delivered_if_recipient_online!(message)
    return unless message.status_sent?
    recipient_online = message.conversation.participants
      .where.not(user_id: message.sender_id)
      .joins(:user)
      .where(users: { online: true })
      .exists?
    if recipient_online
      message.mark_delivered!
      MessageUpdateBroadcastJob.perform_later(message.id)
    end
  end

  # Envia new_message para destinatários na hora (sem esperar Sidekiq), para os dois lados ficarem rápidos.
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
    message.update!(metadata: (message.metadata || {}).merge("new_message_sent_at" => Time.current.utc.iso8601))
    broadcast_sidebar_update(message)
  end

  # Broadcasts sidebar update (conversation list preview) to ALL participants synchronously
  # so the UI updates immediately without depending on Sidekiq being available.
  def broadcast_sidebar_update(message)
    conversation = message.conversation
    renderer = ApplicationController.renderer.new(
      http_host: Rails.application.config.action_mailer.default_url_options&.dig(:host) || "localhost",
      https:     Rails.env.production?
    )
    conversation.participants.includes(:user).each do |participant|
      item_html = renderer.render(
        partial: "conversations/conversation_item",
        locals:  { conversation: conversation, current_user: participant.user }
      )
      preview_html = renderer.render(
        partial: "conversations/conversation_item_preview",
        locals:  { conversation: conversation, current_user: participant.user }
      )
      UserChannel.broadcast_to(participant.user, {
        type:            "conversation_updated",
        conversation_id: conversation.id,
        item_html:       item_html,
        preview_html:    preview_html
      })
    end
  rescue => e
    Rails.logger.error("[broadcast_sidebar_update] Error: #{e.class} #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
  end
end
