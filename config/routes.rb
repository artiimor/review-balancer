# frozen_string_literal: true

Rails.application.routes.draw do
  root to: 'home#index'

  post '/webhooks/github', to: 'webhooks#github'
  post '/webhooks/gitlab', to: 'webhooks#gitlab'

  resources :repositories, only: %i[index new create show destroy] do
    scope module: :repositories do
      resources :contributors, only: %i[index update]
    end
  end
  resource :configuration, only: %i[show update], controller: 'configuration'
  delete '/configuration/github_token', to: 'configuration#destroy_github_token', as: :destroy_github_token
  delete '/configuration/gitlab_token', to: 'configuration#destroy_gitlab_token', as: :destroy_gitlab_token

  # Health check para el load balancer / docker healthcheck.
  get 'up' => 'rails/health#show', as: :rails_health_check

  Rails.application.routes.draw do
    get 'home/index'
    devise_for :users, controllers: {
      sessions: 'users/sessions'
    }
  end
end
