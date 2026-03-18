class Sticker < ApplicationRecord
  belongs_to :user
  has_one_attached :image

  validates :image, presence: true

  def image_url
    return nil unless image.attached?
    Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true)
  end

  def as_json(options = {})
    super(options.merge(only: %i[id name created_at])).merge(
      image_url: image_url
    )
  end
end
