class CreateCampaignDeliveries < ActiveRecord::Migration[7.2]
  def change
    create_table :campaign_deliveries do |t|
      t.references :campaign,       null: false, foreign_key: { to_table: :marketing_campaigns }
      t.references :recipient_user, null: false, foreign_key: { to_table: :users }
      t.references :message,        foreign_key: true
      t.integer    :status,         null: false, default: 0  # queued/sent/delivered/read/clicked/failed
      t.string     :clicked_button_label
      t.string     :clicked_list_row_id
      t.datetime   :delivered_at
      t.datetime   :read_at
      t.datetime   :clicked_at

      t.timestamps
    end

    add_index :campaign_deliveries, %i[campaign_id recipient_user_id], unique: true
  end
end
