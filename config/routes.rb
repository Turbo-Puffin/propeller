Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Authentication
  get  "/login",  to: "sessions#new",      as: :login
  post "/login",  to: "sessions#create"
  delete "/logout", to: "sessions#destroy", as: :logout

  get  "/signup", to: "registrations#new",    as: :signup
  post "/signup", to: "registrations#create"

  get "/dashboard", to: "dashboard#show", as: :dashboard

  namespace :settings do
    resources :api_keys, only: [ :index, :create, :destroy ]
    resources :segments, only: [ :index, :new, :create, :edit, :update, :destroy ]
  end

  namespace :api do
    namespace :v1 do
      resources :contacts, only: [ :index, :show, :create, :update, :destroy ]
      resources :lists, only: [ :index, :show, :create ] do
        post "contacts", on: :member, action: :add_contact
        delete "contacts/:contact_id", on: :member, action: :remove_contact
      end
      resources :campaigns, only: [ :index, :show, :create ] do
        post "schedule", on: :member
        post "cancel", on: :member
      end
      resources :sends, only: [ :index, :show ]
      resources :segments, only: [ :index, :show, :create, :update, :destroy ] do
        get "contacts", on: :member
      end
    end
  end

  root "pages#home"
  post "/waitlist", to: "waitlist#create", as: :waitlist
end
