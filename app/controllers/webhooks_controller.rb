# frozen_string_literal: true

class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  rescue_from ActiveRecord::Encryption::Errors::Base, with: :handle_encryption_error

  def github
    repository = Repository.find_by(github_full_name: payload.dig('repository', 'full_name'), provider: 'github')
    return head :not_found unless repository

    return head :unauthorized unless valid_github_signature?(repository)

    ProcessPullRequestJob.perform_later(repository.id, payload) if github_merge_request_event?

    head :ok
  end

  def gitlab
    repository = Repository.find_by(github_full_name: payload.dig('project', 'path_with_namespace'), provider: 'gitlab')
    return head :not_found unless repository
    return head :unauthorized unless valid_gitlab_signature?(repository)

    ProcessPullRequestJob.perform_later(repository.id, payload) if gitlab_merge_request_event?

    head :ok
  end

  private

  def handle_encryption_error(exception)
    Rails.logger.error("#{self.class}: #{exception.class} - #{exception.message}")
    head :internal_server_error
  end

  def valid_github_signature?(repository)
    Github::GithubSignatureVerifier.valid?(
      payload_body: raw_body,
      signature_header: request.headers['X-Hub-Signature-256'],
      secret: repository.webhook_secret
    )
  end

  def github_merge_request_event?
    event = request.headers['X-GitHub-Event']
    event == 'pull_request' && %w[opened closed review_requested].include?(payload['action'])
  end

  def valid_gitlab_signature?(repository)
    Gitlab::GitlabSignatureVerifier.valid?(
      token_header: request.headers['X-Gitlab-Token'],
      secret: repository.webhook_secret
    )
  end

  def gitlab_merge_request_event?
    request.headers['X-Gitlab-Event'] == 'Merge Request Hook' &&
      %w[open close merge update].include?(payload.dig('object_attributes', 'action'))
  end

  def raw_body
    @raw_body ||= request.raw_post
  end

  def payload
    @payload ||= JSON.parse(raw_body)
  rescue JSON::ParserError
    {}
  end
end
