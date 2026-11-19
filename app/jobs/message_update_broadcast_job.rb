# frozen_string_literal: true

# Broadcasts a message update (delivered / read / soft-deleted) to all participants.
# Replaces the synchronous Message#broadcast_deletion_update call.
class MessageUpdateBroadcastJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message
      .includes(:sender, :read_receipts, conversation: { participants: :user })
      .find_by(id: message_id)
    return unless message

    message.attachment.blob if message.attachment.attached?

    message.conversation.participants.each do |participant|
      html = ApplicationController.renderer.render(
        partial: "messages/message",
        locals: { message: message, current_user: participant.user }
      )
      stream = ApplicationController.helpers.turbo_stream.replace("message_#{message_id}", html)
      ChatChannel.broadcast_to(
        [ message.conversation, participant.user ],
        { type: "message_updated", message_id: message_id, turbo_stream: stream.to_s, html: html }
      )
    end
  end
end
