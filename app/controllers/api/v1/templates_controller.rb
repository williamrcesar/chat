module Api
  module V1
    class TemplatesController < BaseController
      before_action :set_template, only: %i[show update destroy]

      def index
        @templates = Template.order(:category, :name)
        render json: TemplateBlueprint.render(@templates, view: :normal)
      end

      def show
        render json: TemplateBlueprint.render(@template, view: :normal)
      end

      def create
        @template = Template.new(template_params)
        @template.created_by = current_user
        @template.save!
        render json: TemplateBlueprint.render(@template, view: :normal), status: :created
      end

      def update
        @template.update!(template_params)
        render json: TemplateBlueprint.render(@template, view: :normal)
      end

      def destroy
        @template.destroy
        head :no_content
      end

      private

      def set_template
        @template = Template.find(params[:id])
      end

      def template_params
        params.require(:template).permit(:name, :category, :content, variables: [])
      end
    end
  end
end
