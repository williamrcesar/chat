class CreateMarketingTemplates < ActiveRecord::Migration[7.2]
  def change
    create_table :marketing_templates do |t|
      t.references :user,          null: false, foreign_key: true
      t.string     :name,          null: false
      t.string     :header_type,   default: "none"   # none / text / image
      t.string     :header_text
      t.text       :body,          null: false
      t.string     :footer
      t.jsonb      :buttons,       null: false, default: []   # [{label, type, value}]
      t.jsonb      :list_header
      t.jsonb      :list_sections, null: false, default: []   # [{title, rows:[{id,title,desc}]}]

      t.timestamps
    end
  end
end
