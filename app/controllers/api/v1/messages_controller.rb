module Api
  module V1
    class MessagesController < BaseController
      before_action :set_conversation
      before_action :set_message, only: %i[ destroy ]

      def index
        page = (params[:page] || 1).to_i
        @messages = @conversation.messages
                                 .includes(:sender, :reply_to)
                                 .recent
                                 .last(50)
        render json: MessageBlueprint.render(@messages, view: :normal, current_user: current_user)
      end

      def create
        @message = @conversation.messages.build(message_params)
        @message.sender = current_user

        if params[:message][:attachment].present?
          @message.attachment.attach(params[:message][:attachment])
          @message.message_type = detect_message_type(params[:message][:attachment])
        end

        authorize @message
        @message.save!

        render json: MessageBlueprint.render(@message, view: :normal, current_user: current_user),
               status: :created
      end

      def destroy
        authorize @message
        @message.destroy
        head :no_content
      end

      private

      def set_conversation
        @conversation = current_user.conversations.find(params[:conversation_id])
      end

      def set_message
        @message = @conversation.messages.find(params[:id])
      end

      def message_params
        params.require(:message).permit(:content, :reply_to_id, :message_type)
      end

      def detect_message_type(file)
        content_type = file.content_type
        case content_type
        when /image/ then :image
        when /audio/ then :audio
        when /video/ then :video
        else :document
        end
      end
    end
  end
end
