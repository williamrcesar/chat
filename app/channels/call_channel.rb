# 100ms calls: no WebRTC signaling. call_offer is sent from CallsController.
# This channel only handles reject and end_call between peers.
class CallChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
  end

  def unsubscribed
    stop_all_streams
  end

  # Callee rejects the incoming call
  def reject(data)
    caller = User.find_by(id: data["to_user_id"])
    return unless caller

    CallChannel.broadcast_to(caller, {
      type:         "call_rejected",
      from_user_id: current_user.id
    })
  end

  # Either side ends an active call
  def end_call(data)
    peer = User.find_by(id: data["to_user_id"])
    return unless peer

    CallChannel.broadcast_to(peer, {
      type:         "call_ended",
      from_user_id: current_user.id
    })
  end
end
