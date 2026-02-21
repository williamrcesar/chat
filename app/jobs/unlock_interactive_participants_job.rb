class UnlockInteractiveParticipantsJob < ApplicationJob
  queue_as :default

  def perform
    # Find all participants whose interactive lock has expired
    expired = Participant.where("interactive_locked_until < ?", Time.current)
                         .where.not(interactive_locked_until: nil)

    expired.find_each do |participant|
      participant.unlock_interactive!

      # Optionally notify the client that lock expired
      conversation = participant.conversation
      ChatChannel.broadcast_to(
        [ conversation, participant.user ],
        { type: "interactive_unlock", expired: true }
      )
    end
  end
end
