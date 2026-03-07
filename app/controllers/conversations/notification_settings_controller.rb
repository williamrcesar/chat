# frozen_string_literal: true

module Conversations
  class NotificationSettingsController < ApplicationController
    before_action :set_conversation
    before_action :set_participant

    def show
      authorize @conversation
    end

    def update
      authorize @conversation
      if @participant.update(notification_settings_params)
        redirect_to conversation_path(@conversation), notice: "Notificações desta conversa atualizadas."
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    def set_conversation
      @conversation = current_user.conversations.find(params[:conversation_id])
    end

    def set_participant
      @participant = @conversation.participants.find_by!(user: current_user)
    end

    def notification_settings_params
      params.require(:participant).permit(
        :muted,
        :notification_sound,
        :notification_color,
        :notification_icon_type,
        :notification_sound_file,
        :notification_custom_image
      )
    end
  end
end
