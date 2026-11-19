# frozen_string_literal: true

module Admin
  class ConversationPolicy < ApplicationPolicy
    def index?
      role_admin? || supervisor_of_any_company?
    end

    def show?
      return true if role_admin?
      return false unless supervisor_of_any_company?

      # Supervisor can only see conversations of their company (via assignment)
      conversation_belongs_to_supervisor_company?
    end

    def mode?
      show?
    end

    def send_message?
      show?
    end

    def destroy?
      role_admin?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        if user.role_admin?
          scope.all
        elsif user.company_attendants.supervisors.exists?
          company_ids = user.company_attendants.supervisors.pluck(:company_id)
          scope.joins(:conversation_assignment)
               .where(conversation_assignments: { company_id: company_ids })
               .distinct
        else
          scope.none
        end
      end
    end

    private

    def role_admin?
      user.role_admin?
    end

    def supervisor_of_any_company?
      user.company_attendants.supervisors.exists?
    end

    def conversation_belongs_to_supervisor_company?
      return false unless record.conversation_assignment.present?

      company_ids = user.company_attendants.supervisors.pluck(:company_id)
      company_ids.include?(record.conversation_assignment.company_id)
    end
  end
end
