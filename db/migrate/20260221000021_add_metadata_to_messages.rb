class AddMetadataToMessages < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:messages, :metadata)
      add_column :messages, :metadata, :jsonb, null: false, default: {}
    end
    unless index_exists?(:messages, :metadata, name: "index_messages_on_metadata")
      add_index :messages, :metadata, using: :gin, name: "index_messages_on_metadata"
    end
  end
end
