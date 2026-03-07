class CampaignDelivery < ApplicationRecord
  belongs_to :campaign,       class_name: "MarketingCampaign", foreign_key: :campaign_id
  belongs_to :recipient_user, class_name: "User", optional: true
  belongs_to :message, optional: true

  enum :status, {
    queued:    0,
    sent:      1,
    delivered: 2,
    read:      3,
    clicked:   4,
    failed:    5
  }, prefix: true

  after_save :broadcast_kanban_update

  def display_recipient
    if recipient_user.present?
      recipient_user.display_name
    else
      recipient_identifier.presence || "?"
    end
  end

  def unresolved?
    recipient_user_id.blank?
  end

  def advance_to!(new_status, extra = {})
    update!({ status: new_status }.merge(extra))
  end

  private

  def broadcast_kanban_update
    KanbanChannel.broadcast_to(campaign, {
      type:           "delivery_update",
      delivery_id:    id,
      status:         status,
      recipient_name: display_recipient,
      recipient_nick: recipient_user&.nickname,
      clicked_button: clicked_button_label,
      clicked_list:   clicked_list_row_id
    })
  end
end
