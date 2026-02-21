class CreateCompanyAttendants < ActiveRecord::Migration[7.2]
  def change
    create_table :company_attendants do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user,    null: false, foreign_key: true
      t.string  :role_name                          # "Financeiro", "Suporte", "TI", etc.
      t.integer :attendant_type, null: false, default: 0  # human / ai
      t.jsonb   :tags,           null: false, default: [] # ["vip", "técnico", etc.]
      t.integer :status,         null: false, default: 0  # available / busy / offline
      t.boolean :is_supervisor,  null: false, default: false

      t.timestamps
    end

    add_index :company_attendants, %i[company_id user_id], unique: true
    add_index :company_attendants, :status
  end
end
