# frozen_string_literal: true

# Handles all broadcasting for a newly created message (text or file attachment):
#   - new_message broadcast via ChatChannel to recipients
#   - conversation_updated (sidebar preview) via UserChannel to all participants
#   - Web Push notification to recipients with a subscription
#   - touch conversation updated_at
#   - mark message as delivered and enqueue MessageUpdateBroadcastJob
#
# Idempotente: se já rodou para esta mensagem (metadata["broadcasted_at"]), não reenvia.
# Evita duplicata quando o Sidekiq faz retry do job.
class MessageBroadcastJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message
      .includes(:sender, :attachment_attachment, conversation: { participants: { user: :web_push_subscriptions } })
      .find_by(id: message_id)
    return unless message

    # Idempotência: se já processamos este envio, não reenviar (evita loop em retry do Sidekiq)
    meta = message.metadata.is_a?(Hash) ? message.metadata : {}
    if meta["broadcasted_at"].present?
      Rails.logger.info("[MessageBroadcastJob] Skipped message_id=#{message_id} (already broadcasted)")
      return
    end

    # Ensure blob is loaded so the rendered HTML includes the attachment URL
    message.attachment.blob if message.attachment.attached?

    conversation  = message.conversation
    sender_id     = message.sender_id

    # Status "sent" já é definido no controller; não atualizar aqui para não atrasar nem reenviar

    # new_message já foi enviado no controller (broadcast_new_message_to_recipients) para ser rápido nos dois lados
    new_message_already_sent = meta["new_message_sent_at"].present?

    conversation.participants.each do |participant|
      unless new_message_already_sent
        next if participant.user_id == sender_id
        html = ApplicationController.renderer.render(
          partial: "messages/message",
          locals: { message: message, current_user: participant.user }
        )
        ChatChannel.broadcast_to([ conversation, participant.user ], { type: "new_message", message: html, message_id: message.id })
      end

      # Update sidebar preview for all participants
      preview_html = ApplicationController.renderer.render(
        partial: "conversations/conversation_item_preview",
        locals:  { conversation: conversation, current_user: participant.user }
      )
      UserChannel.broadcast_to(participant.user, {
        type:            "conversation_updated",
        conversation_id: conversation.id,
        preview_html:    preview_html
      })

      # Web Push for recipients (not sender, not muted, with subscription)
      next if participant.user_id == sender_id
      next if participant.muted?

      if participant.user.web_push_subscriptions.none?
        Rails.logger.info("[WebPush] Skipped: user_id=#{participant.user_id} has no subscriptions")
        next
      end

      push_payload = build_push_payload_for(message, participant)
      WebPushNotificationJob.perform_later(participant.user_id, push_payload)
      Rails.logger.info("[WebPush] Enqueued push for user_id=#{participant.user_id}")
    end

    # Touch conversation so it bubbles to the top of the sidebar list
    conversation.touch

    # Delivered (2 marcas cinzas): será definido quando o destinatário confirmar recebimento via message_received no ChatChannel (instantâneo).

    # Marca como já broadcastado para este job não reenviar em retry do Sidekiq
    message.update!(metadata: meta.merge("broadcasted_at" => Time.current.utc.iso8601))
  end

  private

  def build_push_payload_for(message, participant)
    icon_url = Rails.application.routes.url_helpers.notification_icon_url(
      token: participant.notification_icon_token
    )
    sound = if participant.notification_sound_file.attached?
              Rails.application.routes.url_helpers.rails_blob_url(participant.notification_sound_file)
            else
              NotificationPreferences.sound_path(participant.effective_notification_sound).presence ||
                NotificationPreferences.sound_path("default")
            end
    {
      title:  message.sender.display_name,
      body:   push_body_for(message),
      icon:   icon_url,
      badge:  "/icon.png",
      sound:  sound,
      color:  participant.effective_notification_color.presence,
      data:   { path: "/conversations/#{message.conversation_id}" }
    }.compact
  end

  def push_body_for(message)
    if message.attachment.attached?
      base = case
             when message.image?    then "sent you an image"
             when message.audio?    then "sent you an audio"
             when message.video?    then "sent you a video"
             when message.document? then "sent you a document"
             else "sent you a file"
             end
      base += ": #{message.content.to_s.truncate(80)}" if message.content.present?
      base
    else
      message.content.to_s.truncate(120)
    end
  end
end
