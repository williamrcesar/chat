class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Backend

  allow_browser versions: :modern

  before_action :authenticate_user!
  before_action :update_user_presence, if: :user_signed_in?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  add_flash_types :info, :success, :warning

  private

  def update_user_presence
    current_user.touch_online! unless current_user.online?
  end

  def user_not_authorized
    flash[:warning] = "Você não tem permissão para realizar esta ação."
    redirect_back(fallback_location: root_path)
  end
end
