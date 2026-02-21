class ConversationAssignment < ApplicationRecord
  belongs_to :conversation
  belongs_to :company
  belongs_to :company_attendant, optional: true

  enum :status, {
    pending:     0,
    active:      1,
    resolved:    2,
    transferred: 3,
    queued:      4
  }, prefix: true

  scope :open,    -> { where(status: %i[ pending active queued ]) }
  scope :recent,  -> { order(created_at: :desc) }

  after_save :broadcast_assignment_update

  def assign_to!(attendant)
    transaction do
      update!(
        company_attendant: attendant,
        status:            :active,
        assigned_at:       Time.current
      )
      attendant.set_status!(:busy)
      # Add attendant to the conversation participants if not already present
      conversation.participants.find_or_create_by!(user: attendant.user) do |p|
        p.role = :member
      end
    end
  end

  def resolve!
    transaction do
      update!(status: :resolved, resolved_at: Time.current)
      # Free the attendant if they have no other active assignments
      if company_attendant
        other_active = ConversationAssignment.status_active
                                             .where(company_attendant: company_attendant)
                                             .where.not(id: id)
                                             .exists?
        company_attendant.set_status!(:available) unless other_active
      end
    end
  end

  def transfer_to!(new_attendant)
    update!(
      company_attendant: new_attendant,
      status:            :transferred,
      assigned_at:       Time.current
    )
    conversation.participants.find_or_create_by!(user: new_attendant.user) { |p| p.role = :member }
  end

  private

  def broadcast_assignment_update
    CompanyChannel.broadcast_to(company, {
      type:                "assignment_update",
      assignment_id:       id,
      status:              status,
      selected_department: selected_department,
      attendant_name:      company_attendant&.user&.display_name,
      conversation_id:     conversation_id
    })
  end
end
