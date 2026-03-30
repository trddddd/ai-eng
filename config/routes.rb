Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get  "login",    to: "sessions#new", as: :login
  post "login",    to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  get  "register", to: "registrations#new",    as: :register
  post "register", to: "registrations#create"

  get "dashboard", to: "dashboard#index", as: :dashboard

  root to: "sessions#new"
end
