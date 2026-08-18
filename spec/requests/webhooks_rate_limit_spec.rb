# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Webhooks rate limiting', type: :request do
  let(:user) { User.create!(email: 'user@example.com', password: 'password123') }
  let!(:repository) { Repository.create!(github_full_name: 'acme/checkout-api', webhook_secret: 's3cr3t', user: user) }
  let(:raw_body) { file_fixture('github_pull_request_opened.json').read }

  around do |example|
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear
    example.run
    Rack::Attack.cache.store.clear
    Rack::Attack.enabled = false
  end

  def signature_for(body, secret)
    "sha256=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret, body)}"
  end

  def post_webhook(body:, secret: 's3cr3t')
    post '/webhooks/github',
         params: body,
         headers: {
           'Content-Type' => 'application/json',
           'X-GitHub-Event' => 'ping',
           'X-Hub-Signature-256' => signature_for(body, secret)
         }
  end

  it 'throttles requests to the webhook endpoints once a single IP exceeds the per-minute limit' do
    30.times { post_webhook(body: raw_body) }
    expect(response).not_to have_http_status(:too_many_requests)

    post_webhook(body: raw_body)

    expect(response).to have_http_status(:too_many_requests)
  end

  it 'counts requests regardless of whether the signature is valid, so guessing the secret is also throttled' do
    30.times { post_webhook(body: raw_body, secret: 'wrong-guess') }

    post_webhook(body: raw_body, secret: 'wrong-guess')

    expect(response).to have_http_status(:too_many_requests)
  end

  it 'rejects webhook bodies larger than the allowed size before processing them' do
    payload = JSON.parse(raw_body)
    payload['padding'] = 'x' * 6.megabytes
    oversized_body = payload.to_json

    post_webhook(body: oversized_body)

    expect(response).to have_http_status(:forbidden)
  end
end
