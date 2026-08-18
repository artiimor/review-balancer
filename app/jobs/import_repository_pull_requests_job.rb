# frozen_string_literal: true

class ImportRepositoryPullRequestsJob < ApplicationJob
  queue_as :default

  def perform(repository_id)
    repository = Repository.find(repository_id)
    importer_class = repository.provider == 'gitlab' ? Gitlab::GitlabPullRequestsImporter : Github::GithubPullRequestsImporter
    lookback = repository.user.configuration&.lookback_months&.months

    if lookback
      importer_class.call(repository, lookback: lookback)
    else
      importer_class.call(repository)
    end
  end
end
