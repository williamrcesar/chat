module CompanyPortal
  class AttendantsController < BaseController
    before_action :require_supervisor!, only: %i[ new create destroy ]
    before_action :set_attendant, only: %i[ edit update destroy toggle_status ]

    def index
      @attendants = @current_company.company_attendants.includes(:user).order(:role_name)
    end

    def new
      @attendant = @current_company.company_attendants.build
    end

    def create
      if create_new_user?
        target_user = build_new_user_from_params
        unless target_user
          @attendant = @current_company.company_attendants.build(attendant_only_params)
          render :new, status: :unprocessable_entity
          return
        end
        target_user.save!
      else
        target_user = find_user_by_identifier(params[:company_attendant][:user_identifier])
        unless target_user
          @attendant = @current_company.company_attendants.build(attendant_only_params)
          flash.now[:alert] = "Usuário não encontrado com esse @nickname ou email."
          render :new, status: :unprocessable_entity
          return
        end
      end

      @attendant = @current_company.company_attendants.build(attendant_only_params)
      @attendant.user = target_user

      if @attendant.save
        redirect_to company_attendants_path, notice: "Atendente #{target_user.display_name} adicionado."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @attendant.update(attendant_only_params)
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
        :role_name, :attendant_type, :is_supervisor, :status, :user_identifier,
        :new_user_email, :new_user_password, :new_user_password_confirmation,
        :new_user_display_name, :new_user_nickname,
        tags: []
      )
    end

    # Params that CompanyAttendant model accepts (exclude user_identifier and new_user_*)
    def attendant_only_params
      attendant_params.slice(:role_name, :attendant_type, :is_supervisor, :status, :tags)
    end

    def create_new_user?
      params[:company_attendant][:new_user_email].present?
    end

    def build_new_user_from_params
      p = params[:company_attendant]
      email    = p[:new_user_email].to_s.strip
      password = p[:new_user_password]
      name     = p[:new_user_display_name].to_s.strip.presence

      if email.blank?
        flash.now[:alert] = "E-mail é obrigatório para criar um novo usuário."
        return nil
      end
      if password.blank? || password.length < 6
        flash.now[:alert] = "Senha é obrigatória e deve ter no mínimo 6 caracteres."
        return nil
      end
      if p[:new_user_password_confirmation].to_s != password
        flash.now[:alert] = "Senha e confirmação não coincidem."
        return nil
      end
      if User.exists?(["lower(email) = ?", email.downcase])
        flash.now[:alert] = "Já existe um usuário com este e-mail."
        return nil
      end

      nickname = p[:new_user_nickname].to_s.strip.downcase.gsub(/\A@/, "").presence
      user = User.new(
        email:                 email.downcase,
        password:              password,
        password_confirmation:  password,
        display_name:          name.presence || email.split("@").first,
        nickname:              nickname
      )
      unless user.valid?
        flash.now[:alert] = user.errors.full_messages.to_sentence
        return nil
      end
      user.save!
      user
    end

    def find_user_by_identifier(identifier)
      return nil if identifier.blank?
      id = identifier.to_s.strip.gsub(/\A@/, "")
      User.find_by("lower(nickname) = ?", id.downcase) ||
        User.find_by(email: identifier.strip)
    end
  end
end
