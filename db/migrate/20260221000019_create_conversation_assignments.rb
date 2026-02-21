class CreateConversationAssignments < ActiveRecord::Migration[7.2]
  def change
    create_table :conversation_assignments do |t|
      t.references :conversation,      null: false, foreign_key: true
      t.references :company,           null: false, foreign_key: true
      t.references :company_attendant, foreign_key: true
      t.integer    :status,            null: false, default: 0  # pending/active/resolved/transferred
      t.string     :selected_department
      t.datetime   :assigned_at
      t.datetime   :resolved_at

      t.timestamps
    end

    add_index :conversation_assignments, :status
  end
end
