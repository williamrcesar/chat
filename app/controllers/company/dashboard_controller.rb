module Company
  class DashboardController < BaseController
    def index
      @assignments_by_status = @current_company.conversation_assignments
                                               .includes(:conversation, company_attendant: :user)
                                               .order(created_at: :desc)
                                               .group_by(&:status)

      @attendants = @current_company.company_attendants
                                    .includes(:user)
                                    .order(:role_name, :status)

      @pending_count  = @current_company.conversation_assignments.status_pending.count
      @queued_count   = @current_company.conversation_assignments.status_queued.count
      @active_count   = @current_company.conversation_assignments.status_active.count
      @resolved_count = @current_company.conversation_assignments.status_resolved.count
    end
  end
end
