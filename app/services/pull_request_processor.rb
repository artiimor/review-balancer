# frozen_string_literal: true

class PullRequestProcessor
  def self.call(repository_id, payload, access_token)
    new(repository_id, payload, access_token).call
  end

  def initialize(repository_id, payload, access_token)
    # TODO: controlar que no sean nil, y loggear un error si lo son
    @repository_id = repository_id
    @payload = payload
    @access_token = access_token
  end

  def call
    if repository_id.blank?
      Rails.logger.error("PullRequestProcessor: repository_id is blank. Payload: #{payload}")
      # TODO: add logs with Sentry or papertrail
      return
    end

    if payload.blank?
      Rails.logger.error("PullRequestProcessor: payload is blank. Repository ID: #{repository_id}")
      # TODO: add logs with Sentry or papertrail
      return
    end

    repository = Repository.find(repository_id)
    processor_for(repository).call(repository, payload, access_token)
  end

  private

  attr_reader :repository_id, :payload, :access_token

  def processor_for(repository)
    repository.provider == 'gitlab' ? Gitlab::GitlabPullRequestProcessor : Github::GithubPullRequestProcessor
  end
end
