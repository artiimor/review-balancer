# frozen_string_literal: true

Rails.application.routes.draw do
  post '/webhooks/github', to: 'webhooks#github'

  # Health check para el load balancer / docker healthcheck.
  get 'up' => 'rails/health#show', as: :rails_health_check
end
