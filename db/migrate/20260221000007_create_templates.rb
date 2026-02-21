class CreateTemplates < ActiveRecord::Migration[7.2]
  def change
    create_table :templates do |t|
      t.string     :name,     null: false
      t.string     :category, null: false, default: "general"
      t.text       :content,  null: false
      t.jsonb      :variables, null: false, default: []
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end
  end
end
