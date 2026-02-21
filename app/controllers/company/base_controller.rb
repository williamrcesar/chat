module Company
  class BaseController < ApplicationController
    layout "company"
    before_action :set_current_company
    before_action :require_company_member!

    private

    def set_current_company
      @current_company = current_user.owned_companies.first ||
                         current_user.companies_as_attendant.first

      unless @current_company
        redirect_to new_company_path, alert: "Você ainda não faz parte de nenhuma empresa."
      end
    end

    def require_company_member!
      unless @current_company&.member?(current_user)
        redirect_to root_path, alert: "Acesso não autorizado."
      end
    end

    def require_supervisor!
      unless @current_company&.supervisor?(current_user)
        redirect_to company_dashboard_path, alert: "Apenas supervisores podem fazer isso."
      end
    end
  end
end
