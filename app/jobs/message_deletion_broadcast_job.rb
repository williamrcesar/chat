# frozen_string_literal: true

# Broadcasts a message_deleted event to all participants after a message is destroyed.
# Receives conversation_id because the Message record no longer exists after destroy.
class MessageDeletionBroadcastJob < ApplicationJob
  queue_as :default

  def perform(message_id, conversation_id)
    conversation = Conversation.includes(participants: :user).find_by(id: conversation_id)
    return unless conversation

    conversation.participants.each do |participant|
      ChatChannel.broadcast_to(
        [ conversation, participant.user ],
        { type: "message_deleted", message_id: message_id }
      )
    end
  end
end
