# Broadcasts to the current user for inbox-level updates (new message in any conversation).
# Used to update the conversation list sidebar in real time.
# Presença: ao abrir o app (subscribed) marca online; ao fechar (unsubscribed) marca último visto.
# Também notifica todas as conversas do usuário para o status "online" / "visto por último" aparecer.
class UserChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
    current_user.touch_online!
    broadcast_presence_to_all_conversations(true)
  end

  def unsubscribed
    stop_all_streams
    current_user.touch_offline!
    broadcast_presence_to_all_conversations(false)
  end

  private

  def broadcast_presence_to_all_conversations(online)
    current_user.conversations.find_each do |conversation|
      conversation.participants.includes(:user).each do |participant|
        next if participant.user_id == current_user.id

        ChatChannel.broadcast_to(
          [ conversation, participant.user ],
          {
            type:       "presence",
            user_id:    current_user.id,
            user_name:  current_user.display_name,
            online:     online,
            last_seen:  current_user.display_last_seen
          }
        )
      end
    end
  end
end
