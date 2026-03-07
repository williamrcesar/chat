class Conversation < ApplicationRecord
  has_one_attached :avatar

  has_many :participants, dependent: :destroy
  has_many :users, through: :participants
  has_many :messages, dependent: :destroy
  has_one  :conversation_assignment, dependent: :destroy
  belongs_to :company, optional: true

  enum :conversation_type, { direct: 0, group: 1 }, prefix: true

  validates :name, presence: true, if: :conversation_type_group?
  validates :conversation_type, presence: true

  scope :for_user,  ->(user) { joins(:participants).where(participants: { user_id: user.id }) }
  scope :recent,    -> { order(updated_at: :desc) }
  scope :active,    ->(user) { joins(:participants).where(participants: { user_id: user.id, archived: false }) }
  scope :archived,  ->(user) { joins(:participants).where(participants: { user_id: user.id, archived: true }) }
  scope :pinned,    ->(user) { joins(:participants).where(participants: { user_id: user.id, pinned: true }) }
  scope :sorted_for, ->(user) {
    joins(:participants)
      .where(participants: { user_id: user.id })
      .order("participants.pinned DESC, conversations.updated_at DESC")
  }

  def last_message
    messages.order(created_at: :desc).first
  end

  # Última reação na conversa (para preview na lista: "Fulano curtiu 👍")
  def last_reaction
    MessageReaction.joins(:message).includes(:user)
      .where(messages: { conversation_id: id })
      .order("message_reactions.created_at DESC")
      .first
  end

  # Se a última atividade foi uma reação (mais recente que a última mensagem), retorna { type: :reaction, user_name:, emoji: }; senão nil (mostrar última mensagem).
  def last_activity_reaction_for_preview
    msg = last_message
    react = last_reaction
    return nil unless react && msg
    return nil if react.created_at <= msg.created_at
    { type: :reaction, user_name: react.user.display_name, emoji: react.emoji }
  end

  def unread_count_for(user)
    participant = participants.find_by(user: user)
    return 0 unless participant
    last_read = participant.last_read_at || Time.at(0)
    messages.where("created_at > ? AND sender_id != ?", last_read, user.id).count
  end

  def display_name_for(current_user)
    return name if conversation_type_group?
    return company.name if is_company_conversation? && company.present?
    other_user = users.where.not(id: current_user.id).first
    other_user&.display_name || "Conversa"
  end

  def other_user(current_user)
    return nil if conversation_type_group?
    users.where.not(id: current_user.id).first
  end

  # Returns the single direct conversation between two users, or creates it.
  # Uses a single DB query to avoid duplicates and N+1.
  def self.find_or_create_direct(user_a, user_b)
    return find_or_create_direct(user_b, user_a) if user_a.id > user_b.id

    existing = joins(:participants)
      .where(conversation_type: :direct)
      .where(participants: { user_id: [ user_a.id, user_b.id ] })
      .where.not(is_company_conversation: true)
      .group(:id)
      .having("COUNT(participants.id) = 2")
      .first
    return existing if existing

    transaction do
      convo = create!(conversation_type: :direct)
      convo.participants.create!(user: user_a, role: :admin)
      convo.participants.create!(user: user_b, role: :admin)
      convo
    end
  end

  # Creates (or finds) a company conversation between a company and a customer
  def self.find_or_create_company_direct(company, customer_user)
    owner = company.owner
    existing = where(conversation_type: :direct, is_company_conversation: true, company: company)
               .joins(:participants)
               .where(participants: { user_id: customer_user.id })
               .first
    return existing if existing

    transaction do
      convo = create!(
        conversation_type:        :direct,
        is_company_conversation:  true,
        company:                  company
      )
      convo.participants.create!(user: owner,         role: :admin)
      convo.participants.create!(user: customer_user, role: :member)
      convo
    end
  end
end
