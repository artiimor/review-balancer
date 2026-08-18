# frozen_string_literal: true

class PullRequestProcessor
  def self.call(repository_id, payload)
    new(repository_id, payload).call
  end

  def initialize(repository_id, payload)
    @repository_id = repository_id
    @payload = payload
  end

  def call
    if repository_id.blank?
      Rails.logger.error("PullRequestProcessor: repository_id is blank. Payload: #{payload}")
      return
    end

    if payload.blank?
      Rails.logger.error("PullRequestProcessor: payload is blank. Repository ID: #{repository_id}")
      return
    end

    repository = Repository.find(repository_id)
    processor_for(repository).call(repository, payload)
  end

  private

  attr_reader :repository_id, :payload

  def processor_for(repository)
    repository.provider == 'gitlab' ? Gitlab::GitlabPullRequestProcessor : Github::GithubPullRequestProcessor
  end
end
