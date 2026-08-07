# frozen_string_literal: true

class ImportRepositoryPullRequestsJob < ApplicationJob
  queue_as :default

  def perform(repository_id, access_token)
    repository = Repository.find(repository_id)
    if repository.provider == 'gitlab'
      Gitlab::GitlabPullRequestsImporter.call(repository, access_token)
    else
      Github::GithubPullRequestsImporter.call(repository, access_token)
    end
  end
end
