Rails.application.routes.draw do
  devise_for :users,
             controllers: {
               registrations: "users/registrations",
               sessions:      "users/sessions"
             }

  authenticated :user do
    root to: "conversations#index", as: :authenticated_root
  end

  root to: redirect("/users/sign_in")

  resources :conversations, only: %i[index show create] do
    member do
      post   :add_participant
      delete "participants/:user_id", action: :remove_participant, as: :remove_participant
      patch  :archive
      patch  :unarchive
      patch  :toggle_pin
    end

    resources :messages, only: [:index, :create] do
      collection do
        post :from_template
        post :forward
        get  :search
      end
      member do
        patch  :mark_read
        delete :delete_for_everyone
      end
    end

    # Reactions: POST /conversations/:conversation_id/messages/:message_id/reactions
    scope "messages/:message_id" do
      post "reactions", to: "message_reactions#create", as: :message_reaction
    end
  end

  resource  :profile, only: %i[show edit update]
  resources :templates

  # Contact requests (nickname-based friendship system)
  resources :contact_requests, only: %i[index create] do
    member do
      patch :accept
      patch :block
    end
  end

  # Marketing — template builder + campaigns + Kanban
  namespace :marketing do
    resources :templates do
      member { get :preview }
    end
    resources :campaigns, only: %i[index show new create] do
      member do
        post :launch
        post :pause
      end
    end
    resources :deliveries, only: [] do
      member do
        post :button_click
        post :list_click
      end
    end
  end

  # Company accounts — creation and public profile
  resources :companies, only: %i[new create show]

  # Company namespace — dashboard, attendants, settings, assignments
  namespace :company do
    get  "dashboard",  to: "dashboard#index",  as: :dashboard
    resource  :settings, only: %i[show edit update]

    resources :attendants do
      member { patch :toggle_status }
    end

    resources :assignments, only: %i[index show] do
      member do
        patch :transfer
        patch :resolve
      end
    end

    # Customer-facing: when they click a department from the menu
    resources :menu_clicks, only: %i[create]
  end

  # Web Push Notifications (PWA)
  resources :web_push_subscriptions, only: %i[create destroy] do
    collection { get :vapid_public_key }
  end

  # Admin dashboard
  namespace :admin do
    root to: "dashboard#index"
    resources :users, only: %i[index show edit update destroy] do
      member { patch :toggle_admin }
    end
    resources :conversations, only: %i[index show destroy]
  end

  # API v1 (JWT auth — for future mobile apps)
  namespace :api do
    namespace :v1 do
      devise_scope :user do
        post   "auth/sign_in",  to: "auth/sessions#create"
        delete "auth/sign_out", to: "auth/sessions#destroy"
        post   "auth/sign_up",  to: "auth/registrations#create"
      end

      resource  :profile, only: %i[show update], controller: "profile"
      resources :templates
      resources :conversations, only: %i[index show create] do
        member do
          get :participants
        end
        resources :messages, only: %i[index create destroy]
      end
    end
  end

  get  "up"            => "rails/health#show",    as: :rails_health_check
  get  "service-worker"=> "rails/pwa#service_worker", as: :pwa_service_worker
  get  "manifest"      => "rails/pwa#manifest",   as: :pwa_manifest
end
