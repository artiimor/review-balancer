# frozen_string_literal: true

class ImportRepositoryPullRequestsJob < ApplicationJob
  queue_as :default

  def perform(repository_id, access_token)
    repository = Repository.find(repository_id)
    importer_class = repository.provider == 'gitlab' ? Gitlab::GitlabPullRequestsImporter : Github::GithubPullRequestsImporter
    lookback = repository.user.configuration&.lookback_months&.months

    if lookback
      importer_class.call(repository, access_token, lookback: lookback)
    else
      importer_class.call(repository, access_token)
    end
  end
end
