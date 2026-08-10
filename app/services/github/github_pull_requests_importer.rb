# frozen_string_literal: true

module Github
  class GithubPullRequestsImporter
    LOOKBACK = 1.year

    def self.call(repository, github_access_token, lookback: LOOKBACK)
      new(repository, github_access_token, lookback: lookback).call
    end

    def initialize(repository, github_access_token, lookback: LOOKBACK)
      # TODO controlar que no sean nil, y loggear un error si lo son
      @repository = repository
      @github_access_token = github_access_token
      @lookback = lookback
    end

    def call
      each_recent_pull_request do |pull_request|
        record_merged_pull_request(pull_request) if pull_request.merged_at
      end
    end

    private

    attr_reader :repository, :lookback

    def each_recent_pull_request
      cutoff = @lookback.ago
      page = github_client.pull_requests(
        repository.github_full_name, state: 'closed', sort: 'created', direction: 'desc', per_page: 100
      )

      loop do
        page.each do |pull_request|
          break if pull_request.created_at < cutoff

          yield pull_request
        end

        next_page = github_client.last_response.rels[:next]
        break unless next_page

        page = github_client.get(next_page.href)
      end
    end

    def record_merged_pull_request(remote_pull_request)
      pull_request = find_or_create_pull_request(remote_pull_request)
      pull_request.update!(state: 'merged', merged_at: remote_pull_request.merged_at)

      record_file_changes(pull_request)
      import_requested_reviewer(pull_request, remote_pull_request) if pull_request.review_assignments.empty?
    end

    def find_or_create_pull_request(remote_pull_request)
      author = Contributor.find_or_create_by!(github_login: remote_pull_request.user.login)

      PullRequest.find_or_create_by!(repository: repository, github_number: remote_pull_request.number) do |record|
        record.author = author
        record.title = remote_pull_request.title
        record.opened_at = remote_pull_request.created_at
      end
    end

    def import_requested_reviewer(pull_request, remote_pull_request)
      login = remote_pull_request.requested_reviewers&.first&.login
      return nil if login.blank?

      reviewer = Contributor.find_or_create_by!(github_login: login)
      RepositoryContributor.find_or_create_by!(repository: repository, contributor: reviewer)
      ReviewAssignment.create!(
        pull_request: pull_request, reviewer: reviewer, assigned_at: Time.current, completed_at: Time.current
      )
    end

    def record_file_changes(pull_request)
      return if pull_request.file_changes.exists?

      github_client.pull_request_files(repository.github_full_name, pull_request.github_number).each do |file|
        FileChange.create!(
          pull_request: pull_request,
          contributor: pull_request.author,
          path: file.filename,
          tech: FileLanguageMapper.tech_for(file.filename),
          lines_changed: file.additions.to_i + file.deletions.to_i
        )
      end
    end

    def github_client
      @github_client ||= Octokit::Client.new(access_token: @github_access_token)
    end
  end
end
