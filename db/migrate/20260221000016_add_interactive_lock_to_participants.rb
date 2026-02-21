class AddInteractiveLockToParticipants < ActiveRecord::Migration[7.2]
  def change
    add_column :participants, :interactive_locked_until, :datetime
    add_column :participants, :interactive_message_id,   :bigint
    add_column :messages,     :message_type_marketing,   :boolean, default: false, null: false
    add_column :messages,     :campaign_delivery_id,     :bigint
  end
end
