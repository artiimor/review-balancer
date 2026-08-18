# frozen_string_literal: true

module Gitlab
  class GitlabPullRequestsImporter
    LOOKBACK = 1.year

    def self.call(repository, lookback: LOOKBACK)
      new(repository, lookback: lookback).call
    end

    def initialize(repository, lookback: LOOKBACK)
      @repository = repository
      @lookback = lookback
    end

    def call
      each_recent_merge_request do |merge_request|
        record_merged_pull_request(merge_request) if merge_request.merged_at
      end
    end

    private

    attr_reader :repository, :lookback

    def each_recent_merge_request
      cutoff = @lookback.ago
      page = 1

      loop do
        merge_requests = gitlab_client.merge_requests(
          repository.github_full_name, state: 'merged', order_by: 'created_at', sort: 'desc', per_page: 100, page: page
        )
        break if merge_requests.empty?

        merge_requests.each do |merge_request|
          break if merge_request.created_at < cutoff

          yield merge_request
        end

        break if merge_requests.last.created_at < cutoff

        page += 1
      end
    end

    def record_merged_pull_request(merge_request)
      pull_request = find_or_create_pull_request(merge_request)
      pull_request.update!(state: 'merged', merged_at: merge_request.merged_at)

      record_file_changes(pull_request)
      import_requested_reviewer(pull_request, merge_request) if pull_request.review_assignments.empty?
    end

    def find_or_create_pull_request(merge_request)
      author = Contributor.find_or_create_by!(github_login: merge_request.author.username)

      PullRequest.find_or_create_by!(repository: repository, github_number: merge_request.iid) do |record|
        record.author = author
        record.title = merge_request.title
        record.opened_at = merge_request.created_at
      end
    end

    def import_requested_reviewer(pull_request, merge_request)
      username = merge_request.reviewers&.first&.username
      return nil if username.blank?

      reviewer = Contributor.find_or_create_by!(github_login: username)
      RepositoryContributor.find_or_create_by!(repository: repository, contributor: reviewer)
      ReviewAssignment.create!(
        pull_request: pull_request, reviewer: reviewer, assigned_at: Time.current, completed_at: Time.current
      )
    end

    def record_file_changes(pull_request)
      return if pull_request.file_changes.exists?

      changes = gitlab_client.merge_request_changes(repository.github_full_name, pull_request.github_number)

      changes.changes.each do |file|
        path = file.new_path || file.old_path

        FileChange.create!(
          pull_request: pull_request,
          contributor: pull_request.author,
          path: path,
          tech: FileLanguageMapper.tech_for(path),
          lines_changed: diff_line_count(file.diff)
        )
      end
    end

    def diff_line_count(diff)
      diff.to_s.lines.count { |line| line.start_with?('+', '-') && !line.start_with?('+++', '---') }
    end

    def gitlab_client
      @gitlab_client ||= repository.user.configuration.gitlab_client(private_token: repository.access_token)
    end
  end
end
