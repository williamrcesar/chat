module Api
  module V1
    class ProfileController < BaseController
      def show
        render json: UserBlueprint.render(current_user, view: :normal)
      end

      def update
        current_user.update!(profile_params)
        render json: UserBlueprint.render(current_user, view: :normal)
      end

      private

      def profile_params
        params.require(:user).permit(:display_name, :phone, :bio)
      end
    end
  end
end
