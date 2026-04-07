Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get  "login",    to: "sessions#new", as: :login
  post "login",    to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  get  "register", to: "registrations#new",    as: :register
  post "register", to: "registrations#create"

  get "dashboard", to: "dashboard#index", as: :dashboard

  get "/audio/sentences/:id", to: "audio#sentence", as: :audio_sentence

  resource :review, only: [:show, :create], controller: "review_sessions"
  resources :cards, only: [] do
    member do
      post :master
    end
  end

  root to: "sessions#new"
end
