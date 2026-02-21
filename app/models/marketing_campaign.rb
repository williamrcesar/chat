class MarketingCampaign < ApplicationRecord
  belongs_to :user
  belongs_to :marketing_template
  has_many :campaign_deliveries, foreign_key: :campaign_id, dependent: :destroy

  enum :status, { draft: 0, running: 1, paused: 2, completed: 3 }, prefix: true

  validates :name, presence: true
  validates :recipient_identifiers, length: { maximum: 1000, message: "cannot exceed 1000 recipients" }

  def total_count    = campaign_deliveries.count
  def queued_count   = campaign_deliveries.status_queued.count
  def sent_count     = campaign_deliveries.status_sent.count
  def delivered_count= campaign_deliveries.status_delivered.count
  def read_count     = campaign_deliveries.status_read.count
  def clicked_count  = campaign_deliveries.status_clicked.count
  def failed_count   = campaign_deliveries.status_failed.count

  def launch!
    update!(status: :running)
    SendCampaignJob.perform_later(id)
  end

  def pause!
    update!(status: :paused)
  end
end
