class ContactRequestsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "contact_requests_#{current_user.id}"
  end

  def unsubscribed
    stop_all_streams
  end
end
