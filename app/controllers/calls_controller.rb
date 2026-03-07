# POST /calls — start a 100ms call: create room, return token to caller, broadcast call_offer to callee.
class CallsController < ApplicationController
  def create
    conversation = Conversation.for_user(current_user).find_by(id: params[:conversation_id])
    unless conversation&.conversation_type_direct?
      return render json: { error: "Conversation not found or not direct" }, status: :unprocessable_entity
    end

    callee = conversation.other_user(current_user)
    unless callee
      return render json: { error: "No other participant" }, status: :unprocessable_entity
    end

    call_type = %w[audio video].include?(params[:call_type]) ? params[:call_type] : "video"
    room_name = "conv-#{conversation.id}-#{SecureRandom.hex(4)}"

    room_id = HmsService.create_room(name: room_name, template_id: ENV["HMS_TEMPLATE_ID"])
    token_caller = HmsService.generate_auth_token(room_id: room_id, user_id: current_user.id, role: "host")
    token_callee = HmsService.generate_auth_token(room_id: room_id, user_id: callee.id, role: "host")

    CallChannel.broadcast_to(callee, {
      type: "call_offer",
      room_id: room_id,
      token: token_callee,
      call_type: call_type,
      caller_name: current_user.display_name,
      caller_id: current_user.id
    })

    render json: { room_id: room_id, token: token_caller }
  rescue HmsService::Error => e
    Rails.logger.error("[CallsController] 100ms error: #{e.message}")
    render json: { error: "Call setup failed" }, status: :service_unavailable
  end
end
