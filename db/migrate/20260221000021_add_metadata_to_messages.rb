class AddMetadataToMessages < ActiveRecord::Migration[7.2]
  def change
    add_column :messages, :metadata, :jsonb, null: false, default: {}
    add_index  :messages, :metadata, using: :gin
  end
end
