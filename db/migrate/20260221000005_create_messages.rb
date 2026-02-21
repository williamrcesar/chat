class CreateMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :sender,       null: false, foreign_key: { to_table: :users }
      t.text       :content
      t.integer    :message_type, null: false, default: 0
      t.integer    :status,       null: false, default: 0
      t.references :reply_to,     foreign_key: { to_table: :messages }
      t.jsonb      :metadata,     null: false, default: {}
      t.timestamps
    end

    add_index :messages, :created_at
  end
end
