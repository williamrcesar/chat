# Busca og:image e og:title da primeira URL no conteúdo da mensagem e guarda em metadata para mostrar preview.
require "open-uri"

class LinkPreviewJob < ApplicationJob
  queue_as :default

  # Regex para a primeira URL http(s) no texto
  URL_REGEX = %r{\bhttps?://[^\s<>"']+(?:[^\s<>"')\].,;:!?]*)?}

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message&.content.present?

    url = message.content[URL_REGEX]
    return if url.blank?

    url = url.strip.gsub(/[.,;:!?)]+$/, "")
    preview = fetch_preview(url)
    return if preview.blank?

    message.update!(metadata: message.metadata.merge("link_preview" => preview))
    message.broadcast_deletion_update
  end

  private

  def fetch_preview(page_url)
    return nil if page_url.blank?

    html = fetch_html(page_url)
    return nil if html.blank?

    doc = Nokogiri::HTML(html)
    image_url = doc.at_css('meta[property="og:image"]')&.attr("content")
    title = doc.at_css('meta[property="og:title"]')&.attr("content")
    description = doc.at_css('meta[property="og:description"]')&.attr("content")

    image_url = absolute_url(image_url, page_url) if image_url.present?

    # Sempre devolver pelo menos o URL para o card ficar clicável mesmo sem og:image/og:title
    {
      "url" => page_url,
      "image_url" => image_url.presence,
      "title" => title.to_s.strip.presence,
      "description" => description.to_s.strip.presence
    }.compact
  end

  def fetch_html(url)
    URI.open(
      url,
      open_timeout: 5,
      read_timeout: 5,
      "User-Agent" => "Mozilla/5.0 (compatible; LinkPreview/1.0)"
    ).read.force_encoding("UTF-8")
  rescue URI::InvalidURIError, SocketError, Timeout::Error, Errno::ECONNREFUSED, OpenURI::HTTPError => _e
    nil
  end

  def absolute_url(href, base_url)
    return nil if href.blank?
    return href if href.start_with?("http://", "https://")
    return "#{URI(base_url).scheme}:#{href}" if href.start_with?("//")

    URI.join(base_url, href).to_s
  rescue URI::InvalidURIError
    href
  end
end
