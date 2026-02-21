class Template < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true

  validates :name, presence: true, uniqueness: true
  validates :content, presence: true
  validates :category, presence: true

  CATEGORIES = %w[general marketing support notification].freeze

  validates :category, inclusion: { in: CATEGORIES }

  def render_with(vars = {})
    result = content.dup
    vars.each do |key, value|
      result.gsub!("{{#{key}}}", value.to_s)
    end
    result
  end
end
