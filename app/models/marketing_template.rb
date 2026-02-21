class MarketingTemplate < ApplicationRecord
  belongs_to :user
  has_one_attached :header_image
  has_many :marketing_campaigns, dependent: :restrict_with_error

  validates :name, presence: true
  validates :body, presence: true
  validates :header_type, inclusion: { in: %w[none text image] }

  def has_buttons?
    buttons.any?
  end

  def has_list?
    list_sections.any?
  end

  def interactive?
    has_buttons? || has_list?
  end

  def preview_text
    parts = []
    parts << "[IMAGE]"     if header_type == "image"
    parts << header_text   if header_type == "text" && header_text.present?
    parts << body
    parts << footer        if footer.present?
    parts.join("\n")
  end
end
