# frozen_string_literal: true

class ImportRepositoryPullRequestsJob < ApplicationJob
  queue_as :default

  def perform(repository_id, github_access_token)
    repository = Repository.find(repository_id)
    Github::GithubPullRequestsImporter.call(repository, github_access_token)
  end
end
