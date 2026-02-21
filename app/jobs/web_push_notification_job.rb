class WebPushNotificationJob < ApplicationJob
  queue_as :default

  # Sends a Web Push notification to all subscriptions of a user.
  # Called when a new message arrives and the recipient is offline.
  def perform(user_id, payload)
    return if VAPID_PUBLIC_KEY.blank? || VAPID_PRIVATE_KEY.blank?

    user = User.find_by(id: user_id)
    return unless user

    user.web_push_subscriptions.find_each do |sub|
      sub.deliver(payload)
    end
  end
end
