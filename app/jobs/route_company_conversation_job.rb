class RouteCompanyConversationJob < ApplicationJob
  queue_as :default

  # Called when a customer clicks a department option from the company menu
  def perform(assignment_id, department_id)
    assignment = ConversationAssignment.includes(:company).find_by(id: assignment_id)
    return unless assignment
    return if assignment.status_active? || assignment.status_resolved?

    company = assignment.company
    service = CompanyRouterService.new(company, assignment)
    service.route(department_id)
  end
end
