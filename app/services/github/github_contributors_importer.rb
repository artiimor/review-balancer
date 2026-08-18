# frozen_string_literal: true

module Github
  class GithubContributorsImporter
    def self.call(repository)
      new(repository).call
    end

    def initialize(repository)
      @repository = repository
    end

    def call
      github_client.contributors(repository.github_full_name).each do |github_contributor|
        contributor = Contributor.find_or_create_by!(github_login: github_contributor.login)
        RepositoryContributor.find_or_create_by!(repository: repository, contributor: contributor)
      end
    end

    private

    attr_reader :repository

    def github_client
      @github_client ||= Octokit::Client.new(access_token: repository.access_token, auto_paginate: true)
    end
  end
end
