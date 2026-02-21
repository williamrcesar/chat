module Admin
  class ConversationsController < BaseController
    before_action :set_conversation, only: %i[ show destroy ]

    def index
      @pagy, @conversations = pagy(
        Conversation.includes(:participants, :messages)
                    .order(updated_at: :desc),
        items: 25
      )
    end

    def show
      @messages = @conversation.messages
                               .includes(:sender)
                               .order(created_at: :desc)
                               .limit(50)
      @participants = @conversation.participants.includes(:user)
    end

    def destroy
      @conversation.destroy
      redirect_to admin_conversations_path, notice: "Conversa removida."
    end

    private

    def set_conversation
      @conversation = Conversation.find(params[:id])
    end
  end
end
