class ConversationPolicy < ApplicationPolicy
  def show?
    participant?
  end

  def create?
    user.present?
  end

  def add_participant?
    admin?
  end

  def remove_participant?
    admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(:participants).where(participants: { user_id: user.id })
    end
  end

  private

  def participant?
    record.participants.exists?(user: user)
  end

  def admin?
    record.participants.exists?(user: user, role: :admin)
  end
end
