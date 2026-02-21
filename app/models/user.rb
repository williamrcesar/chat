class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :trackable,
         :jwt_authenticatable, jwt_revocation_strategy: self

  has_one_attached :avatar

  has_many :participants, dependent: :destroy
  has_many :conversations, through: :participants
  has_many :sent_messages, class_name: "Message", foreign_key: :sender_id, dependent: :destroy
  has_many :read_receipts, dependent: :destroy

  has_many :sent_contact_requests,     class_name: "ContactRequest", foreign_key: :sender_id,   dependent: :destroy
  has_many :received_contact_requests, class_name: "ContactRequest", foreign_key: :receiver_id, dependent: :destroy

  has_many :marketing_templates, dependent: :destroy
  has_many :marketing_campaigns,  dependent: :destroy

  has_many :web_push_subscriptions, dependent: :destroy

  has_many :owned_companies,    class_name: "Company", foreign_key: :owner_id, dependent: :destroy
  has_many :company_attendants, dependent: :destroy
  has_many :companies_as_attendant, through: :company_attendants, source: :company

  enum :role, { regular: 0, admin: 1 }, prefix: true

  validates :display_name, presence: true, length: { maximum: 60 }
  validates :phone,    format: { with: /\A\+?[\d\s\-()]+\z/ }, allow_blank: true
  validates :nickname, uniqueness: { case_sensitive: false }, allow_blank: true,
                       format: { with: /\A[a-z0-9_]{3,30}\z/, message: "only lowercase letters, numbers and underscores (3-30 chars)" }

  before_save :downcase_nickname
  after_create :generate_display_name_if_blank

  def avatar_url
    avatar.attached? ? avatar : nil
  end

  def touch_online!
    update_columns(online: true, last_seen_at: Time.current)
  end

  def touch_offline!
    update_columns(online: false, last_seen_at: Time.current)
  end

  def display_last_seen
    return "online" if online?
    return "nunca visto" unless last_seen_at
    "visto por último #{last_seen_at.strftime('%d/%m/%Y às %H:%M')}"
  end

  def contact_with?(other_user)
    conversations.conversation_type_direct
                 .joins(:participants)
                 .where(participants: { user_id: other_user.id })
                 .exists?
  end

  def pending_contact_requests_count
    received_contact_requests.pending.count
  end

  private

  def downcase_nickname
    self.nickname = nickname.downcase.strip if nickname.present?
  end

  def generate_display_name_if_blank
    update_column(:display_name, email.split("@").first) if display_name.blank?
  end
end
