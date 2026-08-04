# frozen_string_literal: true

class ImportRepositoryContributorsJob < ApplicationJob
  queue_as :default

  def perform(repository_id, github_access_token)
    repository = Repository.find(repository_id)
    GithubContributorsImporter.call(repository, github_access_token)
  end
end
