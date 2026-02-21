class AddCompanyToConversations < ActiveRecord::Migration[7.2]
  def change
    add_column :conversations, :company_id,               :bigint
    add_column :conversations, :is_company_conversation,  :boolean, null: false, default: false
    add_index  :conversations, :company_id
  end
end
