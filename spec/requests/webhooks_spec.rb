# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Webhooks', type: :request do
  include ActiveJob::TestHelper

  let(:user) { User.create!(email: 'user@example.com', password: 'password123') }
  let!(:repository) { Repository.create!(github_full_name: 'acme/checkout-api', webhook_secret: 's3cr3t', user: user) }
  let(:raw_body) { file_fixture('github_pull_request_opened.json').read }

  def signature_for(body, secret)
    "sha256=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret, body)}"
  end

  it 'enqueues ProcessPullRequestJob when signature is valid' do
    signature = signature_for(raw_body, 's3cr3t')

    expect do
      post '/webhooks/github',
           params: raw_body,
           headers: {
             'Content-Type' => 'application/json',
             'X-GitHub-Event' => 'pull_request',
             'X-Hub-Signature-256' => signature
           }
    end.to have_enqueued_job(ProcessPullRequestJob)

    expect(response).to have_http_status(:ok)
  end

  it 'returns 401 if signature does not match' do
    signature = signature_for(raw_body, 'secreto-equivocado')

    post '/webhooks/github',
         params: raw_body,
         headers: {
           'Content-Type' => 'application/json',
           'X-GitHub-Event' => 'pull_request',
           'X-Hub-Signature-256' => signature
         }

    expect(response).to have_http_status(:unauthorized)
  end

  it 'returns 200 without enqueuing a job for events other than pull_request' do
    signature = signature_for(raw_body, 's3cr3t')

    expect do
      post '/webhooks/github',
           params: raw_body,
           headers: {
             'Content-Type' => 'application/json',
             'X-GitHub-Event' => 'ping',
             'X-Hub-Signature-256' => signature
           }
    end.not_to have_enqueued_job(ProcessPullRequestJob)

    expect(response).to have_http_status(:ok)
  end

  it 'returns 200 without enqueuing a job for pull_request actions other than opened/closed' do
    body = raw_body.sub('"action": "opened"', '"action": "synchronize"')
    signature = signature_for(body, 's3cr3t')

    expect do
      post '/webhooks/github',
           params: body,
           headers: {
             'Content-Type' => 'application/json',
             'X-GitHub-Event' => 'pull_request',
             'X-Hub-Signature-256' => signature
           }
    end.not_to have_enqueued_job(ProcessPullRequestJob)

    expect(response).to have_http_status(:ok)
  end

  it 'returns 404 if the repository is not assigned' do
    unknown_body = raw_body.sub('acme/checkout-api', 'acme/otro-repo-no-registrado')
    signature = signature_for(unknown_body, 's3cr3t')

    post '/webhooks/github',
         params: unknown_body,
         headers: {
           'Content-Type' => 'application/json',
           'X-GitHub-Event' => 'pull_request',
           'X-Hub-Signature-256' => signature
         }

    expect(response).to have_http_status(:not_found)
  end
end
