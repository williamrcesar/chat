module Company
  class SettingsController < BaseController
    before_action :require_supervisor!

    def show
      @company = @current_company
    end

    def edit
      @company = @current_company
    end

    def update
      @company = @current_company
      if @company.update(settings_params)
        redirect_to company_settings_path, notice: "Configurações salvas."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def settings_params
      # Parse raw menu JSON from the form or build from structured params
      if params[:menu_json].present?
        begin
          menu = JSON.parse(params[:menu_json])
          params.require(:company).permit(:name, :description, :bio, :logo).merge(menu_config: menu)
        rescue JSON::ParserError
          params.require(:company).permit(:name, :description, :bio, :logo)
        end
      else
        params.require(:company).permit(:name, :description, :bio, :logo)
      end
    end
  end
end
