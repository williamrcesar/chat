class CreateConversations < ActiveRecord::Migration[7.2]
  def change
    create_table :conversations do |t|
      t.string  :name
      t.integer :conversation_type, null: false, default: 0
      t.text    :description
      t.timestamps
    end
  end
end
