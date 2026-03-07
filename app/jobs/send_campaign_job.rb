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
      unless recipient
        Rails.logger.warn "[SendCampaignJob] Identifier não encontrado: #{identifier.inspect} (campaign_id=#{campaign.id})"
        # Cria entrega em "falhou" para aparecer no Kanban
        CampaignDelivery.create!(
          campaign:            campaign,
          recipient_user_id:  nil,
          recipient_identifier: identifier,
          status:             :failed
        )
        next
      end

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
        msg.mark_sent!

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
    raw = identifier.to_s.strip
    return nil if raw.blank?

    # @nickname ou nickname (case-insensitive)
    nick = raw.gsub(/\A@/, "")
    u = User.find_by("lower(nickname) = ?", nick.downcase) if nick.present?
    return u if u

    # E-mail (case-insensitive)
    u = User.find_by("lower(email) = ?", raw.downcase)
    return u if u

    # Telefone exato
    u = User.find_by(phone: raw)
    return u if u

    # Telefone: comparação por só dígitos (ex.: "55 11 99999" = "+5511999999999")
    if raw.match?(/\A\+?[\d\s\-()]+\z/)
      digits = raw.gsub(/\D/, "")
      u = User.where("phone IS NOT NULL AND phone != '' AND REGEXP_REPLACE(phone, '[^0-9]', '', 'g') = ?", digits).first
      return u if u
    end

    # display_name exato (case-insensitive)
    u = User.find_by("lower(display_name) = ?", raw.downcase)
    return u if u

    # display_name contém o termo (ex.: "@Rodrigues" → "João Rodrigues")
    if nick.present?
      pattern = "%#{sanitize_sql_like(nick.downcase)}%"
      User.find_by("lower(display_name) LIKE ? ESCAPE '\\'", pattern)
    end
  end

  def sanitize_sql_like(str)
    str.to_s.gsub(/[%_\\]/) { |c| "\\#{c}" }
  end
end
