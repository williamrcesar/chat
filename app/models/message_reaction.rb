class MessageReaction < ApplicationRecord
  ALLOWED_EMOJIS = %w[👍 ❤️ 😂 😮 😢 🙏].freeze

  belongs_to :message
  belongs_to :user

  validates :emoji, inclusion: { in: ALLOWED_EMOJIS }
  validates :user_id, uniqueness: { scope: [ :message_id, :emoji ] }

  after_create_commit :broadcast_reaction_update
  after_destroy_commit :broadcast_reaction_update

  def self.grouped_for(message)
    where(message: message)
      .group(:emoji)
      .count
  end

  private

  def broadcast_reaction_update
    counts = message.reactions_grouped
    message.conversation.participants.includes(:user).each do |participant|
      ChatChannel.broadcast_to(
        [ message.conversation, participant.user ],
        {
          type: "reaction_update",
          message_id: message_id,
          reactions: counts
        }
      )
    end
  end
end
