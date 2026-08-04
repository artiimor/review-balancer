# frozen_string_literal: true

class GithubContributorsImporter
  def self.call(repository, github_access_token)
    new(repository, github_access_token).call
  end

  def initialize(repository, github_access_token)
    @repository = repository
    @github_access_token = github_access_token
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
    @github_client ||= Octokit::Client.new(access_token: @github_access_token, auto_paginate: true)
  end
end
