# frozen_string_literal: true

class AddNotificationPreferencesToUsersAndParticipants < ActiveRecord::Migration[7.2]
  def change
    # Perfil: padrões de notificação (som, cor, ícone) para novas conversas
    add_column :users, :default_notification_sound, :string, default: "default", null: false
    add_column :users, :default_notification_color, :string
    add_column :users, :default_notification_icon_type, :string, default: "avatar", null: false

    # Por conversa (por participante): mute já existe; som/cor/ícone customizados
    add_column :participants, :notification_sound, :string
    add_column :participants, :notification_color, :string
    add_column :participants, :notification_icon_type, :string
  end
end
