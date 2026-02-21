class MessagePolicy < ApplicationPolicy
  def create?
    record.conversation.participants.exists?(user: user)
  end

  def destroy?
    record.sender == user
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(:conversation)
           .joins("INNER JOIN participants ON participants.conversation_id = conversations.id")
           .where(participants: { user_id: user.id })
    end
  end
end
