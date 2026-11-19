class MessageReactionsController < ApplicationController
  before_action :set_conversation
  before_action :set_message

  def create
    emoji = params[:emoji]
    unless MessageReaction::ALLOWED_EMOJIS.include?(emoji)
      return head :unprocessable_entity
    end

    reactor = reaction_user
    existing = @message.reactions.find_by(user: reactor, emoji: emoji)

    if existing
      existing.destroy
    else
      @message.reactions.where(user: reactor).destroy_all
      @message.reactions.create!(user: reactor, emoji: emoji)
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "reactions_#{@message.id}",
          partial: "messages/message_reactions",
          locals: { message: @message.reload, current_user: reactor }
        )
      end
      format.html { redirect_to conversation_path(@conversation) }
    end
  end

  private

  # When an admin is in "Impersonar" mode, reactions should be made as the impersonated participant.
  def reaction_user
    return current_user unless current_user.role_admin?

    conv_id = session[:admin_impersonate_conversation_id].to_i
    user_id = session[:admin_impersonate_user_id].to_i
    return current_user if conv_id.zero? || user_id.zero?
    return current_user unless @conversation.id == conv_id
    return current_user unless @conversation.participants.exists?(user_id: user_id)

    User.find_by(id: user_id) || current_user
  end

  def set_conversation
    # If an admin is impersonating, allow reacting within that conversation as the impersonated participant.
    # Otherwise, keep the strict participant-only lookup.
    if current_user.role_admin? && session[:admin_impersonate_conversation_id].to_i == params[:conversation_id].to_i
      @conversation = Conversation.find(params[:conversation_id])
    else
      @conversation = current_user.conversations.find(params[:conversation_id])
    end
  end

  def set_message
    @message = @conversation.messages.find(params[:message_id])
  end
end
