class Company < ApplicationRecord
  belongs_to :owner, class_name: "User"

  has_one_attached :logo

  has_many :company_attendants, dependent: :destroy
  has_many :attendant_users, through: :company_attendants, source: :user
  has_many :conversation_assignments, dependent: :destroy

  enum :status, { active: 0, suspended: 1 }, prefix: true

  validates :name,     presence: true, length: { maximum: 80 }
  validates :nickname, presence: true,
                       uniqueness: { case_sensitive: false },
                       format: { with: /\A[a-z0-9_]{3,30}\z/,
                                 message: "only lowercase letters, numbers and underscores (3-30 chars)" }

  before_save :downcase_nickname

  # Default menu config for new companies
  after_create :set_default_menu_config

  scope :by_nickname, ->(nick) { where("lower(nickname) = ?", nick.downcase.gsub(/\A@/, "")) }

  def self.find_by_nickname(nick)
    by_nickname(nick).first
  end

  # Departments defined in menu_config["departments"]
  def departments
    (menu_config["departments"] || [])
  end

  def greeting
    menu_config["greeting"] || "Olá! Como podemos te ajudar?"
  end

  def attendants_for_department(role_name)
    company_attendants.status_available.where(role_name: role_name)
  end

  def has_available_attendant?(role_name)
    attendants_for_department(role_name).exists?
  end

  def supervisor?(user)
    company_attendants.where(user: user, is_supervisor: true).exists? || owner_id == user.id
  end

  def member?(user)
    company_attendants.where(user: user).exists? || owner_id == user.id
  end

  private

  def downcase_nickname
    self.nickname = nickname.downcase.strip if nickname.present?
  end

  def set_default_menu_config
    return if menu_config.present? && menu_config["departments"].present?
    update_column(:menu_config, {
      "greeting"    => "Olá! Como podemos te ajudar? Selecione uma opção abaixo:",
      "departments" => [
        { "id" => "support", "label" => "Suporte Geral",    "role_name" => "Suporte" },
        { "id" => "finance", "label" => "Financeiro",        "role_name" => "Financeiro" },
        { "id" => "ti",      "label" => "Suporte Técnico",  "role_name" => "TI" }
      ]
    })
  end
end
