module Api
  module V1
    module Auth
      class SessionsController < Devise::SessionsController
        include ActionController::MimeResponds
        respond_to :json

        private

        def respond_with(resource, _opts = {})
          render json: {
            message: "Login realizado com sucesso.",
            user: UserBlueprint.render_as_hash(resource, view: :normal),
            token: request.env["warden-jwt_auth.token"]
          }, status: :ok
        end

        def respond_to_on_destroy
          if current_user
            render json: { message: "Logout realizado com sucesso." }, status: :ok
          else
            render json: { message: "Token inválido ou já expirado." }, status: :unauthorized
          end
        end
      end
    end
  end
end
