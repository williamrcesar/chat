class MessageReactionsController < ApplicationController
  before_action :set_conversation
  before_action :set_message

  def create
    emoji = params[:emoji]
    unless MessageReaction::ALLOWED_EMOJIS.include?(emoji)
      return head :unprocessable_entity
    end

    existing = @message.reactions.find_by(user: current_user, emoji: emoji)

    if existing
      existing.destroy
    else
      @message.reactions.where(user: current_user).destroy_all
      @message.reactions.create!(user: current_user, emoji: emoji)
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "reactions_#{@message.id}",
          partial: "messages/message_reactions",
          locals: { message: @message.reload, current_user: current_user }
        )
      end
      format.html { redirect_to conversation_path(@conversation) }
    end
  end

  private

  def set_conversation
    @conversation = current_user.conversations.find(params[:conversation_id])
  end

  def set_message
    @message = @conversation.messages.find(params[:message_id])
  end
end
