class KanbanChannel < ApplicationCable::Channel
  def subscribed
    campaign = current_user.marketing_campaigns.find_by(id: params[:campaign_id])
    if campaign
      stream_for campaign
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end
end
