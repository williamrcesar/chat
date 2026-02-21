class TemplateBlueprint < Blueprinter::Base
  identifier :id

  view :normal do
    fields :name, :category, :content, :variables, :created_at

    field :created_by_name do |template|
      template.created_by&.display_name
    end
  end
end
