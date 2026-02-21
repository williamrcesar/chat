class CreateMarketingCampaigns < ActiveRecord::Migration[7.2]
  def change
    create_table :marketing_campaigns do |t|
      t.references :user,               null: false, foreign_key: true
      t.references :marketing_template, null: false, foreign_key: true
      t.string     :name,               null: false
      t.integer    :status,             null: false, default: 0  # draft/running/paused/completed
      t.jsonb      :recipient_identifiers, null: false, default: []  # nicknames or phones
      t.integer    :daily_limit,        default: 1000
      t.datetime   :scheduled_at

      t.timestamps
    end
  end
end
