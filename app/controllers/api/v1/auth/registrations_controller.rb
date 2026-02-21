module Api
  module V1
    module Auth
      class RegistrationsController < Devise::RegistrationsController
        include ActionController::MimeResponds
        respond_to :json

        private

        def respond_with(resource, _opts = {})
          if resource.persisted?
            render json: {
              message: "Cadastro realizado com sucesso.",
              user: UserBlueprint.render_as_hash(resource, view: :normal)
            }, status: :created
          else
            render json: {
              errors: resource.errors.full_messages
            }, status: :unprocessable_entity
          end
        end
      end
    end
  end
end
