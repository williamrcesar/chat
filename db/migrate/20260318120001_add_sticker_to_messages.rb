class AddStickerToMessages < ActiveRecord::Migration[7.2]
  def change
    # sticker: 8 — message with an attached sticker image, content may be blank
    # We rely on the existing `attachment` via ActiveStorage; no new column needed.
    # The enum value is added in the model; this migration documents the intent.
  end
end
