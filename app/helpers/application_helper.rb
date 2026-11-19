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


  # Matches one emoji grapheme cluster (ZWJ sequences, skin tones, flags, keycaps, etc.)
  EMOJI_RE = /
    (?:
      (?:\p{Emoji_Presentation}|\p{Emoji}\uFE0F)
      \p{Emoji_Modifier}?
      (?:\u200D
         (?:\p{Emoji_Presentation}|\p{Emoji}\uFE0F)
         \p{Emoji_Modifier}?
      )*
    )
    | \p{Regional_Indicator}{2}
    | [0-9#*]\uFE0F?\u20E3
  /xu

  # Strips all whitespace and invisible Unicode codepoints
  EMOJI_STRIP_RE = /[\s\p{Z}\u00A0\u200B-\u200F\u2028\u2029\u202A-\u202F\u2060-\u206F\uFEFF]/u

  # Returns true when text contains only 1–3 emoji grapheme clusters and nothing else visible.
  def emoji_only_text?(text)
    return false if text.blank?
    str = text.to_s.encode("UTF-8", invalid: :replace, undef: :replace).strip
    return false if str.empty?
    cleaned = str.gsub(EMOJI_STRIP_RE, "")
    return false if cleaned.empty?
    emojis = cleaned.scan(EMOJI_RE)
    return false if emojis.empty? || emojis.length > 3
    # After removing all emoji clusters, nothing visible should remain
    cleaned.gsub(EMOJI_RE, "").empty?
  rescue
    false
  end

  # Returns the number of emoji grapheme clusters in text.
  def emoji_grapheme_count(text)
    return 0 if text.blank?
    text.to_s.encode("UTF-8", invalid: :replace, undef: :replace)
        .gsub(EMOJI_STRIP_RE, "")
        .scan(EMOJI_RE).length
  rescue
    0
  end
end
