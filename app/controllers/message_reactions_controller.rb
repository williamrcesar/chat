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
      # Toggle off if same emoji
      existing.destroy
    else
      # Remove any other emoji from this user on this message first
      @message.reactions.where(user: current_user).destroy_all
      @message.reactions.create!(user: current_user, emoji: emoji)
    end

    head :ok
  end

  private

  def set_conversation
    @conversation = current_user.conversations.find(params[:conversation_id])
  end

  def set_message
    @message = @conversation.messages.find(params[:message_id])
  end
end
