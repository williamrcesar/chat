class ConversationBlueprint < Blueprinter::Base
  identifier :id

  view :list do
    fields :name, :conversation_type, :description, :created_at, :updated_at

    field :unread_count do |conversation, options|
      user = options[:current_user]
      user ? conversation.unread_count_for(user) : 0
    end

    field :last_message do |conversation|
      msg = conversation.last_message
      next nil unless msg
      {
        id: msg.id,
        content: msg.content,
        message_type: msg.message_type,
        sender_name: msg.sender&.display_name,
        created_at: msg.created_at
      }
    end

    field :display_name do |conversation, options|
      user = options[:current_user]
      user ? conversation.display_name_for(user) : conversation.name
    end
  end

  view :normal do
    include_view :list

    association :users, blueprint: UserBlueprint, view: :normal
  end
end
