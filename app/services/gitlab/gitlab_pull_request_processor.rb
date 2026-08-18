# frozen_string_literal: true

module Gitlab
  class GitlabPullRequestProcessor
    def self.call(repository, payload)
      new(repository, payload).call
    end

    def initialize(repository, payload)
      @repository = repository
      @payload = payload
    end

    def call
      attrs = payload['object_attributes']

      author = Contributor.find_or_create_by!(github_login: payload.dig('user', 'username'))
      pull_request = find_or_create_pull_request(attrs, author)

      case attrs['action']
      when 'open'
        handle_opened(pull_request)
      when 'merge'
        finalize(pull_request, state: 'merged', merged_at: attrs['updated_at'])
      when 'close'
        finalize(pull_request, state: 'closed')
      when 'update'
        handle_review_requested(pull_request) if payload.dig('changes', 'reviewers').present?
      end
    end

    private

    attr_reader :repository, :payload

    def handle_opened(pull_request)
      record_file_changes(pull_request)
      return if pull_request.review_assignments.exists?

      import_requested_reviewer(pull_request) || ReviewerSelector.assign!(pull_request)
    end

    def import_requested_reviewer(pull_request)
      username = payload['reviewers']&.first&.dig('username')
      return nil if username.blank?

      reviewer = Contributor.find_or_create_by!(github_login: username)
      RepositoryContributor.find_or_create_by!(repository: repository, contributor: reviewer)
      ReviewAssignment.create!(pull_request: pull_request, reviewer: reviewer, assigned_at: Time.current)
    end

    def handle_review_requested(pull_request)
      username = payload['reviewers']&.first&.dig('username')
      return if username.blank? || already_assigned_to?(pull_request, username)

      reviewer = Contributor.find_or_create_by!(github_login: username)
      RepositoryContributor.find_or_create_by!(repository: repository, contributor: reviewer)

      pull_request.review_assignments.where(completed_at: nil).find_each(&:complete!)
      ReviewAssignment.create!(
        pull_request: pull_request, reviewer: reviewer, assigned_at: Time.current, source: 'manual'
      )
    end

    def already_assigned_to?(pull_request, username)
      pull_request.current_review_assignment&.reviewer&.github_login == username
    end

    def finalize(pull_request, state:, merged_at: nil)
      pull_request.update!(state: state, merged_at: merged_at)
      pull_request.review_assignments.where(completed_at: nil).find_each(&:complete!)
      record_file_changes(pull_request) if state == 'merged'
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

    def find_or_create_pull_request(attrs, author)
      PullRequest.find_or_create_by!(repository: repository, github_number: attrs['iid']) do |pr|
        pr.author = author
        pr.title = attrs['title']
        pr.opened_at = attrs['created_at']
      end
    end

    def gitlab_client
      @gitlab_client ||= ::Gitlab.client(
        endpoint: endpoint, private_token: repository.access_token
      )
    end

    def endpoint
      repository.user.configuration.gitlab_api_endpoint
    end
  end
end
