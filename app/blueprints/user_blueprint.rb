class UserBlueprint < Blueprinter::Base
  identifier :id

  view :normal do
    fields :email, :display_name, :phone, :bio, :online, :last_seen_at, :created_at

    field :avatar_url do |user|
      user.avatar.attached? ? Rails.application.routes.url_helpers.rails_blob_url(user.avatar, only_path: true) : nil
    end

    field :last_seen do |user|
      user.display_last_seen
    end
  end
end
