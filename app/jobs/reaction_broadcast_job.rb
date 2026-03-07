# frozen_string_literal: true

# Broadcasts reaction changes (add or remove) to all conversation participants.
#
# For event 'created': pass reaction_id; the reaction record still exists.
# For event 'destroyed': pass message_id, notification and reactor_id are nil
#   because the reaction record is already gone.
class ReactionBroadcastJob < ApplicationJob
  queue_as :default

  def perform(message_id:, event:, reaction_id: nil, notification: nil, reactor_id: nil)
    if event == "created" && reaction_id.present?
      reaction = MessageReaction.find_by(id: reaction_id)
      if reaction
        notification = { "display_name" => reaction.user.display_name, "emoji" => reaction.emoji }
        reactor_id   = reaction.user_id
        message_id   = reaction.message_id
      end
    end

    msg = Message.find_by(id: message_id)
    return if msg.nil?

    conv = msg.conversation

    conv.participants.includes(:user).each do |participant|
      html = ApplicationController.renderer.render(
        partial: "messages/message_reactions",
        locals:  { message: msg, current_user: participant.user }
      )
      payload = { type: "reaction_update", message_id: message_id, html: html }
      if notification.present? && participant.user_id != reactor_id
        payload[:notification] = notification
      end
      ChatChannel.broadcast_to([ conv, participant.user ], payload)
    end

    conv.participants.includes(:user).each do |participant|
      preview_html = ApplicationController.renderer.render(
        partial: "conversations/conversation_item_preview",
        locals:  { conversation: conv, current_user: participant.user }
      )
      UserChannel.broadcast_to(participant.user, {
        type:            "conversation_updated",
        conversation_id: conv.id,
        preview_html:    preview_html
      })
    end
  end
end
