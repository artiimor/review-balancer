# frozen_string_literal: true

class ImportRepositoryContributorsJob < ApplicationJob
  queue_as :default

  def perform(repository_id, access_token)
    repository = Repository.find(repository_id)
    if repository.provider == 'github'
      Github::GithubContributorsImporter.call(repository, access_token)
    elsif repository.provider == 'gitlab'
      Gitlab::GitlabContributorsImporter.call(repository, access_token)
    end
  end
end
