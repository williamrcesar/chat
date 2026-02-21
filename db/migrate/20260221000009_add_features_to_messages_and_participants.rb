class AddFeaturesToMessagesAndParticipants < ActiveRecord::Migration[7.2]
  def change
    # Delete for everyone (soft delete)
    add_column :messages, :deleted_at,           :datetime
    add_column :messages, :deleted_for_everyone,  :boolean, null: false, default: false

    # Forward messages
    add_column :messages, :forwarded_from_id, :bigint
    add_foreign_key :messages, :messages, column: :forwarded_from_id

    # Archived / pinned conversations (stored on the participant join table per user)
    add_column :participants, :archived, :boolean, null: false, default: false
    add_column :participants, :pinned,   :boolean, null: false, default: false

    add_index :messages, :deleted_at
    add_index :messages, :forwarded_from_id
    add_index :participants, :pinned
    add_index :participants, :archived
  end
end
