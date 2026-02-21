class SendCampaignJob < ApplicationJob
  queue_as :default

  def perform(campaign_id)
    campaign = MarketingCampaign.find_by(id: campaign_id)
    return unless campaign&.status_running?

    template = campaign.marketing_template
    sent_today = 0

    campaign.recipient_identifiers.each do |identifier|
      break if sent_today >= campaign.daily_limit
      break unless campaign.reload.status_running?

      recipient = resolve_user(identifier)
      next unless recipient

      # Skip if already delivered
      next if CampaignDelivery.exists?(campaign: campaign, recipient_user: recipient)

      delivery = CampaignDelivery.create!(
        campaign:       campaign,
        recipient_user: recipient,
        status:         :queued
      )

      begin
        conversation = Conversation.find_or_create_direct(campaign.user, recipient)

        msg = conversation.messages.create!(
          sender:             campaign.user,
          content:            template.body,
          message_type:       :marketing,
          campaign_delivery:  delivery
        )

        if template.header_type == "image" && template.header_image.attached?
          msg.attachment.attach(template.header_image.blob)
        end

        delivery.advance_to!(:sent, delivered_at: Time.current)
        delivery.update!(message: msg)

        # Set interactive lock on recipient if template has buttons/lists
        if template.interactive?
          participant = conversation.participants.find_by(user: recipient)
          participant&.lock_interactive!(msg.id)

          ChatChannel.broadcast_to(
            [ conversation, recipient ],
            {
              type:       "interactive_lock",
              message_id: msg.id,
              locked_until: 24.hours.from_now.iso8601
            }
          )
        end

        sent_today += 1

        # Throttle: 1 message per second to avoid rate limits
        sleep 1 if campaign.recipient_identifiers.size > 10

      rescue => e
        delivery.advance_to!(:failed)
        Rails.logger.error "[SendCampaignJob] Failed for #{identifier}: #{e.message}"
      end
    end

    campaign.update!(status: :completed) if campaign.reload.status_running?
  end

  private

  def resolve_user(identifier)
    id = identifier.to_s.strip.gsub(/\A@/, "")
    User.find_by("lower(nickname) = ?", id.downcase) ||
      User.find_by(phone: identifier.to_s.strip)
  end
end
