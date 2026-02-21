class MessageBlueprint < Blueprinter::Base
  identifier :id

  view :normal do
    fields :content, :message_type, :status, :metadata, :created_at
    field :reply_to_id
    field :sender_id

    field :sender do |message|
      {
        id: message.sender.id,
        display_name: message.sender.display_name
      }
    end

    field :attachment_url do |message|
      message.attachment_url
    end

    field :mine do |message, options|
      user = options[:current_user]
      user ? message.sender_id == user.id : false
    end
  end
end
