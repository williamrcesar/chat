module Company
  class AttendantsController < BaseController
    before_action :require_supervisor!, only: %i[ new create destroy ]
    before_action :set_attendant, only: %i[ show edit update destroy toggle_status ]

    def index
      @attendants = @current_company.company_attendants.includes(:user).order(:role_name)
    end

    def new
      @attendant = @current_company.company_attendants.build
    end

    def create
      target_user = find_user_by_identifier(params[:company_attendant][:user_identifier])

      unless target_user
        @attendant = @current_company.company_attendants.build
        flash.now[:alert] = "Usuário não encontrado com esse @nickname ou email."
        render :new, status: :unprocessable_entity
        return
      end

      @attendant = @current_company.company_attendants.build(attendant_params)
      @attendant.user = target_user

      if @attendant.save
        redirect_to company_attendants_path, notice: "Atendente #{target_user.display_name} adicionado."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @attendant.update(attendant_params)
        redirect_to company_attendants_path, notice: "Atendente atualizado."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @attendant.destroy
      redirect_to company_attendants_path, notice: "Atendente removido."
    end

    # PATCH /company/attendants/:id/toggle_status
    def toggle_status
      new_status = params[:status]
      if CompanyAttendant.statuses.key?(new_status)
        @attendant.set_status!(new_status)
        render json: { ok: true, status: @attendant.status }
      else
        render json: { ok: false }, status: :unprocessable_entity
      end
    end

    private

    def set_attendant
      @attendant = @current_company.company_attendants.find(params[:id])
    end

    def attendant_params
      params.require(:company_attendant).permit(
        :role_name, :attendant_type, :is_supervisor, :status, tags: []
      )
    end

    def find_user_by_identifier(identifier)
      return nil if identifier.blank?
      id = identifier.to_s.strip.gsub(/\A@/, "")
      User.find_by("lower(nickname) = ?", id.downcase) ||
        User.find_by(email: identifier.strip)
    end
  end
end
