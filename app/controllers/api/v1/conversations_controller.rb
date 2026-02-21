module Api
  module V1
    class ConversationsController < BaseController
      before_action :set_conversation, only: %i[ show participants ]

      def index
        @conversations = current_user.conversations.includes(:users, :messages).recent
        render json: ConversationBlueprint.render(@conversations, view: :list, current_user: current_user)
      end

      def show
        authorize @conversation
        render json: ConversationBlueprint.render(@conversation, view: :normal, current_user: current_user)
      end

      def create
        if params[:user_id].present?
          other_user = User.find(params[:user_id])
          @conversation = Conversation.find_or_create_direct(current_user, other_user)
        else
          @conversation = Conversation.new(conversation_params)
          @conversation.participants.build(user: current_user, role: :admin)
          authorize @conversation
          @conversation.save!
        end

        render json: ConversationBlueprint.render(@conversation, view: :normal, current_user: current_user),
               status: :created
      end

      def participants
        authorize @conversation
        render json: UserBlueprint.render(@conversation.users, view: :normal)
      end

      private

      def set_conversation
        @conversation = current_user.conversations.find(params[:id])
      end

      def conversation_params
        params.require(:conversation).permit(:name, :description, :conversation_type)
      end
    end
  end
end
