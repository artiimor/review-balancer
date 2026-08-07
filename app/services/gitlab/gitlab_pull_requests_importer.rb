# frozen_string_literal: true

module Gitlab
  class GitlabPullRequestsImporter
    LOOKBACK = 1.year

    def self.call(repository, gitlab_access_token)
      new(repository, gitlab_access_token).call
    end

    def initialize(repository, gitlab_access_token, lookback: LOOKBACK)
      # TODO controlar que no sean nil, y loggear un error si lo son
      @repository = repository
      @gitlab_access_token = gitlab_access_token
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
      author = Contributor.find_or_create_by!(github_login: merge_request.author.username)

      pull_request = PullRequest.find_or_create_by!(
        repository: repository, github_number: merge_request.iid
      ) do |record|
        record.author = author
        record.title = merge_request.title
        record.opened_at = merge_request.created_at
      end

      pull_request.update!(state: 'merged', merged_at: merge_request.merged_at)

      record_file_changes(pull_request)
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
      @gitlab_client ||= ::Gitlab.client(
        endpoint: endpoint, private_token: @gitlab_access_token
      )
    end

    def endpoint
      repository.user.configuration.gitlab_api_endpoint
    end
  end
end
