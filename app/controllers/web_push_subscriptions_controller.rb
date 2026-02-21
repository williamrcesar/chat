class WebPushSubscriptionsController < ApplicationController
  # POST /web_push_subscriptions
  def create
    sub = WebPushSubscription.subscribe!(
      current_user,
      subscription_params.merge(user_agent: request.user_agent)
    )
    render json: { ok: true, id: sub.id }, status: :created
  rescue => e
    render json: { ok: false, error: e.message }, status: :unprocessable_entity
  end

  # DELETE /web_push_subscriptions
  def destroy
    endpoint = params[:endpoint]
    current_user.web_push_subscriptions.find_by(endpoint: endpoint)&.destroy
    render json: { ok: true }
  end

  # GET /web_push_subscriptions/vapid_public_key
  # Returns the VAPID public key so the browser can subscribe
  def vapid_public_key
    render json: { vapid_public_key: VAPID_PUBLIC_KEY }
  end

  private

  def subscription_params
    params.require(:subscription).permit(:endpoint, keys: [:p256dh, :auth])
  end
end
