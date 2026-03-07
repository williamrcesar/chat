# Broadcasts to the current user for inbox-level updates (new message in any conversation).
# Used to update the conversation list sidebar in real time.
class UserChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
  end

  def unsubscribed
    stop_all_streams
  end
end
