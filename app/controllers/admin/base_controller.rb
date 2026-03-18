module Admin
  class BaseController < ApplicationController
    before_action :require_admin_or_supervisor!

    layout "admin"

    private

    def require_admin_or_supervisor!
      return if current_user&.role_admin?
      return if current_user&.company_attendants&.supervisors&.exists?

      redirect_to root_path, alert: "Acesso negado."
    end
  end
end
