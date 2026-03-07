class MessageReaction < ApplicationRecord
  ALLOWED_EMOJIS = %w[👍 ❤️ 😂 😮 😢 🙏].freeze

  belongs_to :message
  belongs_to :user

  validates :emoji, inclusion: { in: ALLOWED_EMOJIS }
  validates :user_id, uniqueness: { scope: [ :message_id, :emoji ] }

  after_create_commit :broadcast_reaction_created
  after_destroy_commit :broadcast_reaction_destroyed

  def self.grouped_for(message)
    where(message: message)
      .group(:emoji)
      .count
  end

  private

  def broadcast_reaction_created
    broadcast_reaction_update(notification: { display_name: user.display_name, emoji: emoji }, reactor_id: user_id)
  end

  def broadcast_reaction_destroyed
    broadcast_reaction_update(notification: nil, reactor_id: nil)
  end

  def broadcast_reaction_update(notification:, reactor_id:)
    msg = Message.find_by(id: message_id)
    return if msg.nil? # Mensagem já foi apagada (ex.: Message.destroy_all)
    conv = msg.conversation
    conv.participants.includes(:user).each do |participant|
      html = ApplicationController.renderer.render(
        partial: "messages/message_reactions",
        locals:  { message: msg, current_user: participant.user }
      )
      payload = {
        type: "reaction_update",
        message_id: message_id,
        html: html
      }
      # Só mostra "fulano curtiu" para os outros, não para quem reagiu
      payload[:notification] = notification if notification.present? && participant.user_id != reactor_id
      ChatChannel.broadcast_to([ conv, participant.user ], payload)
    end

    # Atualiza a lista de conversas na sidebar (ex.: "Fulano curtiu 👍")
    conv.participants.includes(:user).each do |participant|
      preview_html = ApplicationController.renderer.render(
        partial: "conversations/conversation_item_preview",
        locals:  { conversation: conv, current_user: participant.user }
      )
      UserChannel.broadcast_to(participant.user, {
        type:            "conversation_updated",
        conversation_id:  conv.id,
        preview_html:     preview_html
      })
    end
  end
end
