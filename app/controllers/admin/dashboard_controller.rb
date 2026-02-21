module Admin
  class DashboardController < BaseController
    def index
      @stats = {
        total_users:         User.count,
        online_users:        User.where(online: true).count,
        new_users_today:     User.where("created_at >= ?", Time.current.beginning_of_day).count,
        total_conversations: Conversation.count,
        direct_convos:       Conversation.where(conversation_type: :direct).count,
        group_convos:        Conversation.where(conversation_type: :group).count,
        total_messages:      Message.count,
        messages_today:      Message.where("created_at >= ?", Time.current.beginning_of_day).count,
        total_attachments:   ActiveStorage::Attachment.count
      }

      @recent_users    = User.order(created_at: :desc).limit(8)
      @recent_messages = Message.includes(:sender, :conversation)
                                .where(deleted_for_everyone: false)
                                .order(created_at: :desc)
                                .limit(10)

      @messages_by_day = Message.where("created_at >= ?", 7.days.ago)
                                .group("DATE(created_at)")
                                .order("DATE(created_at)")
                                .count
    end
  end
end
