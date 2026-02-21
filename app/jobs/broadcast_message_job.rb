class BroadcastMessageJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.includes(:sender, :conversation).find_by(id: message_id)
    return unless message

    html = ApplicationController.renderer.render(
      partial: "messages/message",
      locals: { message: message, current_user: message.sender }
    )

    ChatChannel.broadcast_to(
      message.conversation,
      { type: "new_message", message: html }
    )
  end
end
