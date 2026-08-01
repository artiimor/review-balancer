# frozen_string_literal: true

class ImportRepositoryPullRequestsJob < ApplicationJob
  queue_as :default

  def perform(repository_id)
    repository = Repository.find(repository_id)
    GithubPullRequestsImporter.call(repository)
  end
end
