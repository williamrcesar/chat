module Company
  class AssignmentsController < BaseController
    before_action :set_assignment, only: %i[ show transfer resolve ]

    def index
      @assignments = @current_company.conversation_assignments
                                     .includes(:conversation, company_attendant: :user)
                                     .order(created_at: :desc)

      # Filter by status
      @assignments = @assignments.where(status: params[:status]) if params[:status].present?

      # Filter by department
      @assignments = @assignments.where(selected_department: params[:department]) if params[:department].present?
    end

    def show
      @conversation = @assignment.conversation
      @messages     = @conversation.messages.visible.includes(:sender).recent
    end

    # PATCH /company/assignments/:id/transfer
    def transfer
      new_attendant = @current_company.company_attendants.find_by(id: params[:attendant_id])
      unless new_attendant
        redirect_to company_assignment_path(@assignment), alert: "Atendente não encontrado."
        return
      end

      @assignment.transfer_to!(new_attendant)
      redirect_to company_assignment_path(@assignment), notice: "Conversa transferida para #{new_attendant.display_name}."
    end

    # PATCH /company/assignments/:id/resolve
    def resolve
      @assignment.resolve!
      redirect_to company_assignments_path, notice: "Atendimento encerrado."
    end

    private

    def set_assignment
      @assignment = @current_company.conversation_assignments.find(params[:id])
    end
  end
end
