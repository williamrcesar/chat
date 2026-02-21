class CreateContactRequests < ActiveRecord::Migration[7.2]
  def change
    create_table :contact_requests do |t|
      t.references :sender,          null: false, foreign_key: { to_table: :users }
      t.references :receiver,        null: false, foreign_key: { to_table: :users }
      t.integer    :status,          null: false, default: 0  # pending / accepted / blocked
      t.string     :preview_text
      t.string     :preview_type     # text / image / template
      t.bigint     :pending_message_id

      t.timestamps
    end

    add_index :contact_requests, %i[sender_id receiver_id], unique: true
  end
end
