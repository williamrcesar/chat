module ApplicationHelper
  include Pagy::Method

  # Converte Markdown para HTML (mensagens do chat). Sanitizado para evitar XSS.
  def render_markdown(text)
    return "" if text.blank?

    markdown = Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(filter_html: true, hard_wrap: true),
      autolink: true,
      no_intra_emphasis: true,
      fenced_code_blocks: true,
      strikethrough: true,
      tables: true,
      hard_wrap: true
    )
    html = markdown.render(text.to_s)
    sanitize(html, tags: %w[p br strong b em i code pre a ul ol li blockquote h1 h2 h3 hr], attributes: %w[href class])
  end
end
