class Message < ApplicationRecord
  include PgSearch::Model

  belongs_to :conversation
  belongs_to :sender, class_name: "User"
  belongs_to :reply_to,       class_name: "Message", optional: true
  belongs_to :forwarded_from, class_name: "Message", foreign_key: :forwarded_from_id, optional: true

  has_one_attached :attachment
  has_many :read_receipts, dependent: :destroy
  has_many :reactions, class_name: "MessageReaction", dependent: :destroy
  belongs_to :campaign_delivery, optional: true

  enum :message_type, {
    text: 0, image: 1, audio: 2, video: 3, document: 4, template: 5, marketing: 6,
    company_menu: 7
  }, prefix: :type

  enum :status, { sent: 0, delivered: 1, read: 2 }, prefix: true

  validates :content, presence: true, if: -> { attachment.blank? && !deleted_for_everyone? }
  validates :message_type, presence: true

  # Full-text search via pg_search
  pg_search_scope :search_content,
    against: :content,
    using: { tsearch: { prefix: true, dictionary: "portuguese" } }

  scope :visible,  -> { where(deleted_for_everyone: false) }
  scope :recent,   -> { order(created_at: :asc) }
  scope :not_deleted, -> { where(deleted_at: nil) }

  after_create_commit  :broadcast_to_participants
  after_create_commit  :touch_conversation
  after_destroy_commit :broadcast_deletion

  def reactions_grouped
    reactions.group(:emoji).count
  end

  def soft_delete_for_everyone!
    update!(deleted_for_everyone: true, deleted_at: Time.current, content: nil)
    attachment.purge if attachment.attached?
    broadcast_deletion_update
  end

  def forwarded?
    forwarded_from_id.present?
  end

  def attachment_url
    return nil unless attachment.attached?
    Rails.application.routes.url_helpers.rails_blob_path(attachment, only_path: true)
  end

  def image?    = type_image?    || (attachment.attached? && attachment.content_type.start_with?("image/"))
  def audio?    = type_audio?    || (attachment.attached? && attachment.content_type.start_with?("audio/"))
  def video?    = type_video?    || (attachment.attached? && attachment.content_type.start_with?("video/"))
  def document? = type_document? || (attachment.attached? && !image? && !audio? && !video?)

  private

  def broadcast_to_participants
    conversation.participants.includes(:user).each do |participant|
      html = ApplicationController.renderer.render(
        partial: "messages/message",
        locals: { message: self, current_user: participant.user }
      )
      ChatChannel.broadcast_to([ conversation, participant.user ], { type: "new_message", message: html })

      # Push notification for offline recipients only (skip sender)
      next if participant.user_id == sender_id
      next if participant.user.online?
      next if participant.user.web_push_subscriptions.none?

      push_payload = {
        title:   sender.display_name,
        body:    push_body,
        icon:    "/icon.png",
        badge:   "/icon.png",
        data:    { path: "/conversations/#{conversation_id}" }
      }
      WebPushNotificationJob.perform_later(participant.user_id, push_payload)
    end
  end

  def push_body
    return "sent you an image"    if attachment.attached? && image?
    return "sent you an audio"    if attachment.attached? && audio?
    return "sent you a video"     if attachment.attached? && video?
    return "sent you a document"  if attachment.attached? && document?
    content.to_s.truncate(100)
  end

  def touch_conversation
    conversation.touch
  end

  def broadcast_deletion
    conversation.participants.includes(:user).each do |participant|
      ChatChannel.broadcast_to(
        [ conversation, participant.user ],
        { type: "message_deleted", message_id: id }
      )
    end
  end

  def broadcast_deletion_update
    html_by_user = {}
    conversation.participants.includes(:user).each do |participant|
      html = ApplicationController.renderer.render(
        partial: "messages/message",
        locals: { message: self, current_user: participant.user }
      )
      ChatChannel.broadcast_to(
        [ conversation, participant.user ],
        { type: "message_updated", message_id: id, html: html }
      )
    end
  end
end
