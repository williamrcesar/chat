class CompanyAttendant < ApplicationRecord
  belongs_to :company
  belongs_to :user

  has_many :conversation_assignments, dependent: :nullify

  enum :attendant_type, { human: 0, ai: 1 }, prefix: true
  enum :status, { available: 0, busy: 1, offline: 2 }, prefix: true

  validates :role_name, presence: true
  validates :user_id,   uniqueness: { scope: :company_id, message: "is already an attendant in this company" }

  scope :available, -> { where(status: 0) }
  scope :supervisors, -> { where(is_supervisor: true) }

  after_save :broadcast_status_change

  def display_name
    "#{user.display_name} (#{role_name})"
  end

  def set_status!(new_status)
    update!(status: new_status)
  end

  private

  def broadcast_status_change
    return unless saved_change_to_status?
    CompanyChannel.broadcast_to(company, {
      type:           "attendant_status",
      attendant_id:   id,
      user_name:      user.display_name,
      role_name:      role_name,
      status:         status,
      is_supervisor:  is_supervisor
    })
  end
end
