# frozen_string_literal: true

class AddRecipientIdentifierAndOptionalUserToCampaignDeliveries < ActiveRecord::Migration[7.1]
  def up
    add_column :campaign_deliveries, :recipient_identifier, :string

    remove_index :campaign_deliveries, name: "index_campaign_deliveries_on_campaign_id_and_recipient_user_id"
    change_column_null :campaign_deliveries, :recipient_user_id, true
    add_index :campaign_deliveries, %i[campaign_id recipient_user_id],
              unique: true,
              where: "recipient_user_id IS NOT NULL",
              name: "index_campaign_deliveries_on_campaign_and_user_uniq"
  end

  def down
    remove_index :campaign_deliveries, name: "index_campaign_deliveries_on_campaign_and_user_uniq"
    execute "DELETE FROM campaign_deliveries WHERE recipient_user_id IS NULL"
    change_column_null :campaign_deliveries, :recipient_user_id, false
    add_index :campaign_deliveries, %i[campaign_id recipient_user_id], unique: true,
              name: "index_campaign_deliveries_on_campaign_id_and_recipient_user_id"
    remove_column :campaign_deliveries, :recipient_identifier
  end
end
