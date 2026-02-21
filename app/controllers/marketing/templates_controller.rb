module Marketing
  class TemplatesController < BaseController
    before_action :set_template, only: %i[ show edit update destroy preview ]

    def index
      @templates = current_user.marketing_templates.order(created_at: :desc)
    end

    def show; end

    def new
      @template = MarketingTemplate.new(header_type: "none", buttons: [], list_sections: [])
    end

    def edit; end

    def create
      @template = current_user.marketing_templates.build(template_params)
      if @template.save
        redirect_to marketing_template_path(@template), notice: "Template criado com sucesso."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @template.update(template_params)
        redirect_to marketing_template_path(@template), notice: "Template atualizado."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @template.destroy
      redirect_to marketing_templates_path, notice: "Template removido."
    end

    def preview
      render partial: "marketing/templates/preview", locals: { template: @template }
    end

    private

    def set_template
      @template = current_user.marketing_templates.find(params[:id])
    end

    def template_params
      params.require(:marketing_template).permit(
        :name, :header_type, :header_text, :body, :footer, :header_image,
        buttons: %i[ label type value ],
        list_header: %i[ text ],
        list_sections: [ :title, rows: %i[ id title desc ] ]
      )
    end
  end
end
