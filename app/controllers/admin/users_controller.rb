module Admin
  class UsersController < BaseController
    before_action :set_user, only: %i[ show edit update destroy toggle_admin ]

    def index
      @pagy, @users = pagy(
        User.order(created_at: :desc),
        items: 25
      )
      @q = params[:q]
      if @q.present?
        @pagy, @users = pagy(
          User.where("display_name ILIKE ? OR email ILIKE ?", "%#{@q}%", "%#{@q}%")
              .order(created_at: :desc),
          items: 25
        )
      end
    end

    def show
    end

    def edit
    end

    def update
      if @user.update(user_params)
        redirect_to admin_user_path(@user), notice: "Usuário atualizado."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @user.destroy
      redirect_to admin_users_path, notice: "Usuário removido."
    end

    def toggle_admin
      if @user == current_user
        redirect_to admin_users_path, alert: "Você não pode alterar seu próprio role."
      elsif @user.role_admin?
        @user.update!(role: :regular)
        redirect_to admin_users_path, notice: "#{@user.display_name} rebaixado para usuário regular."
      else
        @user.update!(role: :admin)
        redirect_to admin_users_path, notice: "#{@user.display_name} promovido a admin."
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:display_name, :email, :phone, :bio, :role)
    end
  end
end
