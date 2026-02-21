class CreateParticipants < ActiveRecord::Migration[7.2]
  def change
    create_table :participants do |t|
      t.references :user,         null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.integer    :role,         null: false, default: 0
      t.datetime   :last_read_at
      t.boolean    :muted,        null: false, default: false
      t.timestamps
    end

    add_index :participants, [ :user_id, :conversation_id ], unique: true
  end
end
