class CreateCompanies < ActiveRecord::Migration[7.2]
  def change
    create_table :companies do |t|
      t.references :owner,       null: false, foreign_key: { to_table: :users }
      t.string     :name,        null: false
      t.string     :nickname,    null: false
      t.string     :description
      t.text       :bio
      t.integer    :status,      null: false, default: 0  # active / suspended
      t.jsonb      :menu_config, null: false, default: {}

      t.timestamps
    end

    add_index :companies, :nickname, unique: true
    # owner_id index is created automatically by t.references above
  end
end
