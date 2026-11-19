# frozen_string_literal: true

# Sons e ícones padrão para notificações. Áudios em public/sounds/ (máx 6s para custom).
module NotificationPreferences
  DEFAULT_SOUNDS = [
    { id: "default", name: "Padrão", path: "/sounds/notification.mp3" },
    { id: "ding", name: "Sino", path: "/sounds/ding.mp3" },
    { id: "chime", name: "Chime", path: "/sounds/chime.mp3" },
    { id: "pop", name: "Pop", path: "/sounds/pop.mp3" },
    { id: "soft", name: "Suave", path: "/sounds/soft.mp3" }
  ].freeze

  ICON_TYPES = %w[avatar color custom_image].freeze

  def self.sound_ids
    DEFAULT_SOUNDS.map { |s| s[:id] }
  end

  def self.sound_path(id)
    DEFAULT_SOUNDS.find { |s| s[:id].to_s == id.to_s }&.dig(:path) || DEFAULT_SOUNDS.first[:path]
  end
end
