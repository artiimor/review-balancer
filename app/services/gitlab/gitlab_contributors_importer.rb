# frozen_string_literal: true

module Gitlab
  class GitlabContributorsImporter
    def self.call(repository)
      new(repository).call
    end

    def initialize(repository)
      # TODO: asegurarnos que no son nil
      @repository = repository
    end

    def call
      gitlab_client.all_members(repository.github_full_name).auto_paginate do |member|
        contributor = Contributor.find_or_create_by!(github_login: member.username)
        RepositoryContributor.find_or_create_by!(repository: repository, contributor: contributor)
      end
    end

    private

    attr_reader :repository

    def gitlab_client
      @gitlab_client ||= ::Gitlab.client(
        endpoint: repository.user.configuration.gitlab_api_endpoint, private_token: repository.access_token
      )
    end
  end
end
