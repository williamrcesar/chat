class StickersController < ApplicationController
  before_action :authenticate_user!

  def index
    stickers = current_user.stickers.with_attached_image.order(created_at: :desc)
    render json: stickers
  end

  def create
    sticker = current_user.stickers.build(name: params.dig(:sticker, :name))

    image_file = params.dig(:sticker, :image)
    if image_file.blank?
      render json: { error: "Imagem obrigatória" }, status: :unprocessable_entity
      return
    end

    sticker.image.attach(image_file)

    if sticker.save
      render json: sticker, status: :created
    else
      render json: { error: sticker.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  def update
    sticker = current_user.stickers.find(params[:id])
    image_file = params.dig(:sticker, :image)
    sticker.image.attach(image_file) if image_file.present?
    sticker.name = params.dig(:sticker, :name) if params.dig(:sticker, :name).present?
    if sticker.save
      render json: sticker
    else
      render json: { error: sticker.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  def destroy
    sticker = current_user.stickers.find(params[:id])
    sticker.destroy
    head :no_content
  end
end
