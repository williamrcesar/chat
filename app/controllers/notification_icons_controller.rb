# frozen_string_literal: true

# Serves notification icon/image for Web Push (avatar, color block, or custom image).
# Uses signed token so the URL can be called by the browser without auth.
class NotificationIconsController < ActionController::Base
  skip_before_action :verify_authenticity_token
  before_action :verify_token

  def show
    case @payload[:type]
    when "avatar"
      serve_avatar
    when "color"
      serve_color
    when "custom_image"
      serve_custom_image
    else
      head :not_found
    end
  end

  private

  def verify_token
    raw = params.require(:token)
    @payload = Rails.application.message_verifier(:notification_icon).verify(raw)
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActionController::ParameterMissing
    head :not_found
  end

  def serve_avatar
    conv = Conversation.find_by(id: @payload[:conversation_id])
    return head :not_found unless conv

    if conv.avatar.attached?
      redirect_to rails_blob_url(conv.avatar), allow_other_host: true
    else
      user = @payload[:other_user_id].present? ? User.find_by(id: @payload[:other_user_id]) : conv.users.first
      if user&.avatar&.attached?
        redirect_to rails_blob_url(user.avatar), allow_other_host: true
      else
        serve_color_placeholder("#6a7175")
      end
    end
  end

  def serve_color
    hex = @payload[:color].presence || "#00a884"
    serve_color_placeholder(hex)
  end

  def serve_custom_image
    part = Participant.find_by(id: @payload[:participant_id])
    return head :not_found unless part&.notification_custom_image&.attached?

    redirect_to rails_blob_url(part.notification_custom_image), allow_other_host: true
  end

  def serve_color_placeholder(hex)
    color = hex.to_s.delete("#")
    r, g, b = color.length == 6 ? color.scan(/.{2}/).map { |x| x.to_i(16) } : [106, 113, 117]
    png = build_1x1_png(r, g, b)
    send_data png, type: "image/png", disposition: "inline"
  end

  def build_1x1_png(r, g, b)
    sig = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a].pack("C*")
    ihdr_data = [1, 1, 8, 2, 0, 0, 0].pack("NNCCCCC")
    raw_row = [0, r, g, b].pack("C4")  # filter 0 + RGB
    idat_data = Zlib.deflate(raw_row, Zlib::BEST_COMPRESSION)
    sig + png_chunk("IHDR", ihdr_data) + png_chunk("IDAT", idat_data) + png_chunk("IEND", "")
  end

  def png_chunk(type, data)
    [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N")
  end
end
