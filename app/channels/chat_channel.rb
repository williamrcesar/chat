class ChatChannel < ApplicationCable::Channel
  def subscribed
    @conversation = current_user.conversations.find_by(id: params[:conversation_id])

    if @conversation
      # Per-user stream so each person receives messages rendered from their perspective
      stream_for [ @conversation, current_user ]
      current_user.touch_online!
      broadcast_presence(true)
      broadcast_interactive_lock_state
    else
      reject
    end
  end

  def unsubscribed
    current_user.touch_offline!
    broadcast_presence(false) if @conversation
    stop_all_streams
  end

  def typing(data)
    return unless @conversation

    # Broadcast typing to all OTHER participants in the conversation
    @conversation.participants.includes(:user).each do |participant|
      next if participant.user_id == current_user.id

      ChatChannel.broadcast_to(
        [ @conversation, participant.user ],
        {
          type: "typing",
          user_id: current_user.id,
          user_name: current_user.display_name,
          typing: data["typing"]
        }
      )
    end
  end

  def mark_read(data)
    return unless @conversation
    participant = @conversation.participants.find_by(user: current_user)
    participant&.mark_read!
  end

  private

  def broadcast_interactive_lock_state
    return unless @conversation
    participant = @conversation.participants.find_by(user: current_user)
    return unless participant&.interactively_locked?

    ChatChannel.broadcast_to(
      [ @conversation, current_user ],
      {
        type:         "interactive_lock",
        locked_until: participant.interactive_locked_until.iso8601
      }
    )
  end

  def broadcast_presence(online)
    @conversation.participants.includes(:user).each do |participant|
      next if participant.user_id == current_user.id

      ChatChannel.broadcast_to(
        [ @conversation, participant.user ],
        {
          type: "presence",
          user_id: current_user.id,
          user_name: current_user.display_name,
          online: online,
          last_seen: current_user.display_last_seen
        }
      )
    end
  end
end
