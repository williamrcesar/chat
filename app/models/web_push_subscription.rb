class WebPushSubscription < ApplicationRecord
  belongs_to :user

  validates :endpoint, :p256dh, :auth, presence: true
  validates :endpoint, uniqueness: true

  def self.subscribe!(user, params)
    find_or_create_by!(endpoint: params[:endpoint]) do |sub|
      sub.user       = user
      sub.p256dh     = params.dig(:keys, :p256dh)
      sub.auth       = params.dig(:keys, :auth)
      sub.user_agent = params[:user_agent]
    end
  end

  # Send a push notification to this subscription.
  # Automatically removes stale subscriptions (410 Gone).
  def deliver(payload)
    Webpush.payload_send(
      endpoint:    endpoint,
      message:     payload.to_json,
      p256dh:      p256dh,
      auth:        auth,
      vapid: {
        subject:     VAPID_SUBJECT,
        public_key:  VAPID_PUBLIC_KEY,
        private_key: VAPID_PRIVATE_KEY
      }
    )
  rescue Webpush::ExpiredSubscription, Webpush::InvalidSubscription
    destroy
  rescue => e
    Rails.logger.error("[WebPush] Failed to deliver to #{endpoint}: #{e.message}")
  end
end
