module Company
  # Called when a customer clicks a department option in a company menu message.
  # This is a public-facing endpoint (no company membership required).
  class MenuClicksController < ApplicationController
    def create
      assignment = ConversationAssignment.find_by(id: params[:assignment_id])

      unless assignment
        render json: { ok: false, error: "Not found" }, status: :not_found
        return
      end

      # Make sure the current user is the customer (participant), not a company member
      unless assignment.conversation.participants.exists?(user: current_user)
        render json: { ok: false, error: "Unauthorized" }, status: :forbidden
        return
      end

      department_id = params[:department_id]

      RouteCompanyConversationJob.perform_later(assignment.id, department_id)

      render json: { ok: true, message: "Aguardando atendente..." }
    end
  end
end
