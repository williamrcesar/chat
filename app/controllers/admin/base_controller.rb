module Admin
  class BaseController < ApplicationController
    before_action :require_admin!

    layout "admin"

    private

    def require_admin!
      unless current_user&.role_admin?
        redirect_to root_path, alert: "Acesso negado."
      end
    end
  end
end
