# frozen_string_literal: true

module Gitlab
  class GitlabContributorsImporter
    def self.call(repository, gitlab_access_token)
      new(repository, gitlab_access_token).call
    end

    def initialize(repository, gitlab_access_token)
      # TODO asegurarnos que no son nil
      @repository = repository
      @gitlab_access_token = gitlab_access_token
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
        endpoint: repository.user.configuration.gitlab_api_endpoint, private_token: @gitlab_access_token
      )
    end
  end
end
