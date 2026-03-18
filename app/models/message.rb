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
    company_menu: 7, sticker: 8
  }, prefix: :type

  # pending = na fila; sent = enviada; delivered = recebida; read = lida
  enum :status, { pending: 0, sent: 1, delivered: 2, read: 3 }, prefix: true

  validates :content, presence: true, if: -> { attachment.blank? && !deleted_for_everyone? && !type_sticker? }
  validates :message_type, presence: true

  # Full-text search via pg_search
  pg_search_scope :search_content,
    against: :content,
    using: { tsearch: { prefix: true, dictionary: "portuguese" } }

  scope :visible,    -> { where(deleted_for_everyone: false) }
  scope :recent,    -> { order(sequence: :asc) }
  scope :not_deleted, -> { where(deleted_at: nil) }

  before_validation :strip_content
  before_create :set_sequence
  after_create_commit  -> { MessageBroadcastJob.perform_later(id) }
  after_destroy_commit -> { MessageDeletionBroadcastJob.perform_later(id, conversation_id) }

  def reactions_grouped
    reactions.group(:emoji).count
  end

  def soft_delete_for_everyone!
    update!(deleted_for_everyone: true, deleted_at: Time.current, content: nil)
    attachment.purge if attachment.attached?
    MessageUpdateBroadcastJob.perform_later(id)
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

  def read_receipt_for(user)
    read_receipts.find { |rr| rr.user_id == user.id }
  end

  # Sequência única por conversa (1, 2, 3...) para ordem e referência sempre iguais
  def set_sequence
    return if sequence.present?
    self.sequence = (conversation.messages.maximum(:sequence) || 0) + 1
  end

  # Status + data numa só tabela: enviada, recebida, lida, pendente
  def mark_sent!
    return if status_sent? || status_delivered? || status_read?
    now = Time.current
    update_columns(status: Message.statuses[:sent], sent_at: now)
  end

  def mark_delivered!
    return if status_delivered? || status_read?
    now = Time.current
    update_columns(status: Message.statuses[:delivered], delivered_at: now)
  end

  def mark_read!
    return if status_read?
    now = Time.current
    update_columns(status: Message.statuses[:read], read_at: now)
  end

  # Atualiza para :read quando todos os destinatários têm ReadReceipt; grava read_at
  def advance_to_read_if_receipts_complete!
    return if status_read?
    recipient_user_ids = conversation.participants.where.not(user_id: sender_id).pluck(:user_id)
    return if recipient_user_ids.empty?
    return unless read_receipts.where(user_id: recipient_user_ids).distinct.count >= recipient_user_ids.size

    self.mark_read!
    MessageUpdateBroadcastJob.perform_now(id)
  end

  private

  def strip_content
    self.content = content.to_s.strip.presence
  end
end
