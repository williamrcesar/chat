# 100ms calls: no WebRTC signaling. call_offer is sent from CallsController.
# This channel handles reject, end_call and call_accepted (so caller can get "Fulano atendeu" push).
class CallChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
  end

  def unsubscribed
    stop_all_streams
  end

  # Callee accepted and joined the room — notify caller (and optional push "Fulano atendeu")
  def call_accepted(data)
    caller = User.find_by(id: data["to_user_id"])
    return unless caller

    CallChannel.broadcast_to(caller, { type: "call_accepted", from_user_id: current_user.id })

    path = if data["conversation_id"].present?
             conv = Conversation.find_by(id: data["conversation_id"])
             conv ? Rails.application.routes.url_helpers.conversation_path(conv) : Rails.application.routes.url_helpers.conversations_path
           else
             Rails.application.routes.url_helpers.conversations_path
           end
    WebPushNotificationJob.perform_later(
      caller.id,
      { title: "Chamada atendida", body: "#{current_user.display_name} atendeu", data: { path: path, tag: "call" } }
    )
  end

  # Callee rejects the incoming call
  def reject(data)
    caller = User.find_by(id: data["to_user_id"])
    return unless caller

    CallChannel.broadcast_to(caller, {
      type:         "call_rejected",
      from_user_id: current_user.id
    })

    # Push: "Fulano não atendeu"
    WebPushNotificationJob.perform_later(
      caller.id,
      {
        title: "Chamada não atendida",
        body:  "#{current_user.display_name} não atendeu",
        data:  { path: Rails.application.routes.url_helpers.conversations_path, tag: "call" }
      }
    )
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
