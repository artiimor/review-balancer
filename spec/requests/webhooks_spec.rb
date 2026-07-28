# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Webhooks', type: :request do
  include ActiveJob::TestHelper

  let!(:repository) { Repository.create!(github_full_name: 'arturo/demo', webhook_secret: 's3cr3t') }
  let(:raw_body) { file_fixture('github_pull_request_opened.json').read }

  def signature_for(body, secret)
    "sha256=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret, body)}"
  end

  it 'encola ProcessPullRequestJob cuando la firma es válida' do
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

  it 'devuelve 401 si la firma no coincide' do
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

  it 'devuelve 404 si el repositorio no está registrado' do
    unknown_body = raw_body.sub('arturo/demo', 'arturo/otro-repo-no-registrado')
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
