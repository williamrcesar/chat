module Marketing
  class DeliveriesController < ApplicationController
    # Skip marketing layout for these — they're AJAX endpoints from inside the chat
    skip_before_action :verify_authenticity_token, only: []

    # POST /marketing/deliveries/:id/button_click
    def button_click
      delivery = CampaignDelivery.joins(:recipient_user)
                                 .find_by!(id: params[:id], recipient_user: current_user)

      delivery.advance_to!(:clicked,
        clicked_button_label: params[:button_label],
        clicked_at:           Time.current
      )

      # Unlock the participant's interactive lock in this conversation
      if delivery.message&.conversation
        participant = delivery.message.conversation.participants.find_by(user: current_user)
        participant&.unlock_interactive!

        # Broadcast unlock to the client
        ChatChannel.broadcast_to(
          [ delivery.message.conversation, current_user ],
          { type: "interactive_unlock" }
        )
      end

      render json: { ok: true, status: delivery.status }
    end

    # POST /marketing/deliveries/:id/list_click
    def list_click
      delivery = CampaignDelivery.joins(:recipient_user)
                                 .find_by!(id: params[:id], recipient_user: current_user)

      delivery.advance_to!(:clicked,
        clicked_list_row_id: params[:row_id],
        clicked_at:          Time.current
      )

      if delivery.message&.conversation
        participant = delivery.message.conversation.participants.find_by(user: current_user)
        participant&.unlock_interactive!

        ChatChannel.broadcast_to(
          [ delivery.message.conversation, current_user ],
          { type: "interactive_unlock" }
        )
      end

      render json: { ok: true, status: delivery.status }
    end
  end
end
