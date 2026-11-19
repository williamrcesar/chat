class WebPushNotificationJob < ApplicationJob
  queue_as :default

  # Sends a Web Push notification to all subscriptions of a user.
  def perform(user_id, payload)
    if VAPID_PUBLIC_KEY.blank? || VAPID_PRIVATE_KEY.blank?
      Rails.logger.warn("[WebPush] Skipped: VAPID keys not set in .env")
      return
    end

    user = User.find_by(id: user_id)
    unless user
      Rails.logger.warn("[WebPush] Skipped: user_id=#{user_id} not found")
      return
    end

    count = user.web_push_subscriptions.count
    if count.zero?
      Rails.logger.info("[WebPush] User #{user_id} has no subscriptions (enable notifications in the app on each device)")
      return
    end

    user.web_push_subscriptions.find_each do |sub|
      sub.deliver(payload)
    end
    Rails.logger.info("[WebPush] Sent to #{count} subscription(s) for user_id=#{user_id}")
  end
end
