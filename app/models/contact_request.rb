class ContactRequest < ApplicationRecord
  belongs_to :sender,   class_name: "User"
  belongs_to :receiver, class_name: "User"

  enum :status, { pending: 0, accepted: 1, blocked: 2 }, prefix: true

  validates :sender_id, uniqueness: { scope: :receiver_id, message: "already sent a request to this user" }

  scope :pending, -> { where(status: 0) }

  after_create_commit :notify_receiver

  def accept!
    transaction do
      update!(status: :accepted)
      # Create the direct conversation and deliver the pending message
      conversation = Conversation.find_or_create_direct(sender, receiver)
      if pending_message_id.present?
        original = Message.find_by(id: pending_message_id)
        if original
          msg = conversation.messages.create!(
            sender:       original.sender,
            content:      original.content,
            message_type: original.message_type
          )
          msg.attachment.attach(original.attachment.blob) if original.attachment.attached?
        end
      end
      conversation
    end
  end

  def block!
    update!(status: :blocked)
  end

  def preview_display
    case preview_type
    when "image"    then "📷 Enviou uma imagem"
    when "template" then preview_text.presence || "📋 Enviou um template"
    else
      preview_text.to_s.truncate(80)
    end
  end

  private

  def notify_receiver
    # Broadcast a notification to the receiver's contact_requests channel
    ActionCable.server.broadcast(
      "contact_requests_#{receiver_id}",
      {
        type:         "new_request",
        id:           id,
        sender_name:  sender.display_name,
        sender_nick:  sender.nickname,
        preview:      preview_display,
        preview_type: preview_type
      }
    )
  end
end
