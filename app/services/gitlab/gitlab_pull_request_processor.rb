# frozen_string_literal: true

module Gitlab
  class GitlabPullRequestProcessor
    def self.call(repository, payload, access_token)
      new(repository, payload, access_token).call
    end

    def initialize(repository, payload, access_token)
      @repository = repository
      @payload = payload
      @access_token = access_token
    end

    def call
      # TODO: control de errores cuando faltan estas claves en el payload
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
      end
    end

    private

    attr_reader :repository, :payload

    def handle_opened(pull_request)
      record_file_changes(pull_request)
      ReviewerSelector.assign!(pull_request)
    end

    def finalize(pull_request, state:, merged_at: nil)
      pull_request.update!(state: state, merged_at: merged_at)
      record_file_changes(pull_request) if state == 'merged'

      pull_request.review_assignments.where(completed_at: nil).find_each(&:complete!)
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
        endpoint: endpoint, private_token: @access_token
      )
    end

    def endpoint
      repository.user.configuration.gitlab_api_endpoint
    end
  end
end
