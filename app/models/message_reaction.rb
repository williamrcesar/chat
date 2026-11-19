class MessageReaction < ApplicationRecord
  # Used by reactions (validation) and by the emoji picker modal.
  EMOJI_CATEGORIES = {
    "Recentes / Favoritos" => %w[👍 ❤️ 😂 🙏 🔥 🎉 😮 😢],
    "Carinhas" => %w[
      😀 😃 😄 😁 😆 😅 😂 🤣 😊 😇 😉 😍 😘 😜 🤪 🤔 😮 😴 😭 😡 😎 🥳
    ],
    "Gestos" => %w[
      👍 👎 👏 🙌 🤝 🙏 🤞 ✌️ 🤟 🤘 👊 ✊ 🤙 👋 🫶
    ],
    "Corações" => %w[
      ❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❤️‍🔥 ❤️‍🩹 💖 💘 💝 💞 💓 💗 💟
    ],
    "Objetos / Símbolos" => %w[
      ✅ ❌ ☑️ ⚠️ ⭐️ 🌟 🔥 💯 🎯 📌 📎 🔔 🧠 💡 🕐 🗑️
    ],
    "Animais / Natureza" => %w[
      🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🌿 🌸 🌻 🌙 ☀️ 🌧️
    ],
    "Comida" => %w[
      🍕 🍔 🍟 🌭 🍿 🥤 ☕️ 🍺 🍷 🍩 🍪 🍫 🍎 🍌 🍉 🍓 🍇
    ],
    "Viagem / Lugares" => %w[
      🚗 🚌 🚕 🚲 ✈️ 🚀 🛳️ 🗺️ 🏖️ 🏙️ 🏠 ⛺️
    ]
  }.freeze

  ALLOWED_EMOJIS = EMOJI_CATEGORIES.values.flatten.uniq.freeze

  belongs_to :message
  belongs_to :user

  validates :emoji, inclusion: { in: ALLOWED_EMOJIS }
  validates :user_id, uniqueness: { scope: [ :message_id, :emoji ] }

  before_destroy :capture_message_id_for_broadcast

  after_create_commit  -> { ReactionBroadcastJob.perform_later(message_id: message_id, event: "created", reaction_id: id) }
  after_destroy_commit -> { ReactionBroadcastJob.perform_later(message_id: @message_id_for_broadcast, event: "destroyed") }

  def self.grouped_for(message)
    where(message: message)
      .group(:emoji)
      .count
  end

  private

  def capture_message_id_for_broadcast
    @message_id_for_broadcast = message_id
  end
end
