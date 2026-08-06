# frozen_string_literal: true

class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def github
    repository = Repository.find_by(github_full_name: payload['repository']['full_name'])
    return head :not_found unless repository

    unless Github::GithubSignatureVerifier.valid?(
      payload_body: raw_body,
      signature_header: request.headers['X-Hub-Signature-256'],
      secret: repository.webhook_secret
    )
      return head :unauthorized
    end

    event = request.headers['X-GitHub-Event']

    if event == 'pull_request' && %w[opened closed].include?(payload['action'])
      ProcessPullRequestJob.perform_later(repository.id, payload, repository.user.configuration&.github_access_token)
    end

    head :ok
  end

  private

  def raw_body
    @raw_body ||= request.raw_post
  end

  def payload
    @payload ||= JSON.parse(raw_body)
  end
end
