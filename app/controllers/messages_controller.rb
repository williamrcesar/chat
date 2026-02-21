class MessagesController < ApplicationController
  before_action :set_conversation
  before_action :set_message, only: %i[ delete_for_everyone ]

  def create
    @message = @conversation.messages.build(message_params)
    @message.sender = current_user

    if params[:message][:attachment].present?
      @message.attachment.attach(params[:message][:attachment])
      @message.message_type = detect_message_type(params[:message][:attachment])
    end

    authorize @message

    if @message.save
      @conversation.participants.find_by(user: current_user)&.mark_read!
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to conversation_path(@conversation) }
      end
    else
      redirect_to conversation_path(@conversation), alert: "Não foi possível enviar a mensagem."
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
    head :ok
  end

  def index
    @pagy, messages = pagy(
      @conversation.messages
                   .visible
                   .includes(:sender, :reply_to, :reactions, attachment_attachment: :blob)
                   .order(created_at: :desc),
      items: 40,
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
    params.require(:message).permit(:content, :reply_to_id)
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
end
