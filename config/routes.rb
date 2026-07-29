# frozen_string_literal: true

Rails.application.routes.draw do
  root to: 'repositories#index'

  post '/webhooks/github', to: 'webhooks#github'

  resources :repositories, only: %i[index new create show destroy]

  # Health check para el load balancer / docker healthcheck.
  get 'up' => 'rails/health#show', as: :rails_health_check

  Rails.application.routes.draw do
    get 'home/index'
    devise_for :users, controllers: {
      sessions: 'users/sessions'
    }
  end
end
