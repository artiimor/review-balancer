# frozen_string_literal: true

class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def github
    repository = Repository.find_by(github_full_name: payload['repository']['full_name'], provider: 'github')
    return head :not_found unless repository

    return head :unauthorized unless valid_github_signature?(repository)

    if github_merge_request_event?
      ProcessPullRequestJob.perform_later(repository.id, payload, repository.user.configuration&.github_access_token)
    end

    head :ok
  end

  def gitlab
    repository = Repository.find_by(github_full_name: payload.dig('project', 'path_with_namespace'), provider: 'gitlab')
    return head :not_found unless repository
    return head :unauthorized unless valid_gitlab_signature?(repository)

    if gitlab_merge_request_event?
      ProcessPullRequestJob.perform_later(repository.id, payload, repository.user.configuration&.gitlab_access_token)
    end

    head :ok
  end

  private

  def valid_github_signature?(repository)
    Github::GithubSignatureVerifier.valid?(
      payload_body: raw_body,
      signature_header: request.headers['X-Hub-Signature-256'],
      secret: repository.webhook_secret
    )
  end

  def github_merge_request_event?
    event = request.headers['X-GitHub-Event']
    event == 'pull_request' && %w[opened closed].include?(payload['action'])
  end

  def valid_gitlab_signature?(repository)
    Gitlab::GitlabSignatureVerifier.valid?(
      token_header: request.headers['X-Gitlab-Token'],
      secret: repository.webhook_secret
    )
  end

  def gitlab_merge_request_event?
    request.headers['X-Gitlab-Event'] == 'Merge Request Hook' &&
      %w[open close merge].include?(payload.dig('object_attributes', 'action'))
  end

  def raw_body
    @raw_body ||= request.raw_post
  end

  def payload
    @payload ||= JSON.parse(raw_body)
  end
end
