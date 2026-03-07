class Participant < ApplicationRecord
  belongs_to :user
  belongs_to :conversation

  enum :role, { member: 0, admin: 1 }, prefix: true

  validates :user_id, uniqueness: { scope: :conversation_id }

  scope :active,   -> { where(archived: false) }
  scope :pinned,   -> { where(pinned: true) }
  scope :archived, -> { where(archived: true) }

  def mark_read!
    now = Time.current
    update!(last_read_at: now)
    # Criar ReadReceipts para mensagens não lidas (para os ícones enviado/entregue/lido)
    conversation.messages
      .where("created_at <= ?", now)
      .where.not(sender_id: user_id)
      .find_each do |msg|
        next if msg.read_receipts.exists?(user_id: user_id)

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
end
