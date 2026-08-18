# frozen_string_literal: true

class ImportRepositoryContributorsJob < ApplicationJob
  queue_as :default

  def perform(repository_id)
    repository = Repository.find(repository_id)
    if repository.provider == 'github'
      Github::GithubContributorsImporter.call(repository)
    elsif repository.provider == 'gitlab'
      Gitlab::GitlabContributorsImporter.call(repository)
    end
  end
end
