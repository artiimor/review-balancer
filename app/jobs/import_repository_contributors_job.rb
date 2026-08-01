# frozen_string_literal: true

class ImportRepositoryContributorsJob < ApplicationJob
  queue_as :default

  def perform(repository_id)
    repository = Repository.find(repository_id)
    GithubContributorsImporter.call(repository)
  end
end
