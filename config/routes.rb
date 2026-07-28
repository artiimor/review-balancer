# frozen_string_literal: true

Rails.application.routes.draw do
  get 'home/index'
  root to: 'home#index'

  post '/webhooks/github', to: 'webhooks#github'

  # Health check para el load balancer / docker healthcheck.
  get 'up' => 'rails/health#show', as: :rails_health_check

  Rails.application.routes.draw do
    get 'home/index'
    devise_for :users, controllers: {
      sessions: 'users/sessions'
    }
  end
end
