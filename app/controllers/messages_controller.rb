class MessagesController < ApplicationController
  before_action :set_conversation
  before_action :set_message, only: %i[ delete_for_everyone ]

  def create
    raw = Array(params.dig(:message, :attachment)).compact_blank
    attachments = raw.select { |a| a.respond_to?(:tempfile) && a.tempfile.present? }
    content = message_params[:content].presence

    if attachments.size > 1
      # Vários anexos: uma mensagem por arquivo (primeira pode ter texto)
      base = message_params.to_h.symbolize_keys.slice(:content, :reply_to_id)
      @messages = attachments.each_with_index.map do |file, i|
        msg = @conversation.messages.build(
          base.merge(content: i.zero? ? content : nil, sender: current_user)
        )
        msg.attachment.attach(file)
        msg.message_type = detect_message_type(file)
        authorize msg
        msg.save! ? msg : nil
      end.compact
      if @messages.any?
        @messages.each { |msg| fetch_link_preview_now(msg) }
        @conversation.participants.find_by(user: current_user)&.mark_read!
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to conversation_path(@conversation) }
        end
      else
        redirect_to conversation_path(@conversation), alert: "Não foi possível enviar."
      end
    else
      # Um anexo ou só texto (não passar attachment ao build — evita "expected attachable, got []")
      @message = @conversation.messages.build(message_params.except(:attachment))
      @message.sender = current_user
      if attachments.one?
        @message.attachment.attach(attachments.first)
        @message.message_type = detect_message_type(attachments.first)
      end
      authorize @message
      if @message.save
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
    params.require(:message).permit(:content, :reply_to_id, attachment: [])
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

  # Busca o preview de link já na resposta para aparecer no turbo_stream; também faz broadcast para os outros.
  def fetch_link_preview_now(message)
    return unless message.content.to_s.match?(%r{\bhttps?://})
    LinkPreviewJob.perform_now(message.id)
    message.reload
  end
end
