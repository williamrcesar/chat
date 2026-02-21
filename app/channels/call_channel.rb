class CallChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
  end

  def unsubscribed
    stop_all_streams
  end

  # Caller initiates: send offer SDP to callee
  def offer(data)
    callee = User.find_by(id: data["to_user_id"])
    return unless callee

    CallChannel.broadcast_to(callee, {
      type:            "call_offer",
      from_user_id:    current_user.id,
      from_user_name:  current_user.display_name,
      conversation_id: data["conversation_id"],
      call_type:       data["call_type"],   # "audio" or "video"
      sdp:             data["sdp"]
    })
  end

  # Callee accepts and sends answer SDP back to caller
  def answer(data)
    caller = User.find_by(id: data["to_user_id"])
    return unless caller

    CallChannel.broadcast_to(caller, {
      type:         "call_answer",
      from_user_id: current_user.id,
      sdp:          data["sdp"]
    })
  end

  # ICE candidates exchange (both directions)
  def ice_candidate(data)
    peer = User.find_by(id: data["to_user_id"])
    return unless peer

    CallChannel.broadcast_to(peer, {
      type:         "ice_candidate",
      from_user_id: current_user.id,
      candidate:    data["candidate"]
    })
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
