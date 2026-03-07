class Participant < ApplicationRecord
  include NotificationPreferences

  belongs_to :user
  belongs_to :conversation

  has_one_attached :notification_sound_file  # áudio customizado (máx 6s)
  has_one_attached :notification_custom_image

  enum :role, { member: 0, admin: 1 }, prefix: true

  validates :user_id, uniqueness: { scope: :conversation_id }
  validates :notification_icon_type, inclusion: { in: ICON_TYPES }, allow_nil: true
  validate :notification_sound_file_constraints, if: -> { notification_sound_file.attached? }

  scope :active,   -> { where(archived: false) }
  scope :pinned,   -> { where(pinned: true) }
  scope :archived, -> { where(archived: true) }

  def mark_read!
    now = Time.current
    previous_last_read = last_read_at
    update!(last_read_at: now)

    # Só processar mensagens do outro desde o último mark_read (evita centenas de queries em conversas longas)
    scope = conversation.messages
      .where("created_at <= ?", now)
      .where.not(sender_id: user_id)
    scope = scope.where("created_at > ?", previous_last_read) if previous_last_read.present?
    message_ids = scope.limit(1000).pluck(:id)
    return if message_ids.empty?

    # Uma query para saber quais já têm read_receipt deste usuário (em vez de N exists?)
    existing_receipt_message_ids = ReadReceipt.where(message_id: message_ids, user_id: user_id).pluck(:message_id)
    ids_without_receipt = message_ids - existing_receipt_message_ids
    return if ids_without_receipt.empty?

    Message.where(id: ids_without_receipt).find_each do |msg|
      ReadReceipt.find_or_create_by!(message: msg, user: user) { |rr| rr.read_at = now }
      msg.advance_to_read_if_receipts_complete!
    end
  end

  def archive!
    update!(archived: true)
  end

  def unarchive!
    update!(archived: false)
  end

  def toggle_pin!
    update!(pinned: !pinned)
  end

  def interactively_locked?
    interactive_locked_until.present? && interactive_locked_until > Time.current
  end

  def lock_interactive!(message_id, duration = 24.hours)
    update!(interactive_locked_until: duration.from_now, interactive_message_id: message_id)
  end

  def unlock_interactive!
    update!(interactive_locked_until: nil, interactive_message_id: nil)
  end

  # Preferência efetiva (conversa ou padrão do usuário)
  def effective_notification_sound
    notification_sound.presence || user.default_notification_sound
  end

  def effective_notification_color
    notification_color.presence || user.default_notification_color
  end

  def effective_notification_icon_type
    notification_icon_type.presence || user.default_notification_icon_type
  end

  # Token assinado para a URL do ícone da notificação (avatar, color ou custom_image)
  def notification_icon_token
    type = effective_notification_icon_type
    payload = case type
              when "avatar"
                other = conversation.other_user(user)
                { type: "avatar", conversation_id: conversation_id, other_user_id: other&.id }
              when "color"
                { type: "color", color: effective_notification_color.presence || "#00a884" }
              when "custom_image"
                { type: "custom_image", participant_id: id }
              else
                { type: "avatar", conversation_id: conversation_id, other_user_id: conversation.other_user(user)&.id }
              end
    Rails.application.message_verifier(:notification_icon).generate(payload, expires_in: 24.hours)
  end

  private

  # Tamanho máx ~600 KB (proxy para ~6s em MP3 comum). Se blob tiver metadata["duration"], valida 6s.
  def notification_sound_file_constraints
    blob = notification_sound_file.blob
    return unless blob

    if blob.byte_size > 600.kilobytes
      errors.add(:notification_sound_file, "deve ter no máximo ~6 segundos (arquivo muito grande)")
    end
    if blob.metadata["duration"].present? && blob.metadata["duration"].to_f > 6
      errors.add(:notification_sound_file, "deve ter no máximo 6 segundos")
    end
  end
end
