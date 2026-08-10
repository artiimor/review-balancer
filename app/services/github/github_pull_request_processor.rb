# frozen_string_literal: true

module Github
  class GithubPullRequestProcessor
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
      pr_data = payload['pull_request']

      author = Contributor.find_or_create_by!(github_login: pr_data['user']['login'])
      pull_request = find_or_create_pull_request(pr_data, author)

      case payload['action']
      when 'opened'
        handle_opened(pull_request, pr_data)
      when 'closed'
        handle_closed(pull_request, pr_data)
      end
    end

    private

    attr_reader :repository, :payload

    def handle_opened(pull_request, pr_data)
      record_file_changes(pull_request)
      return if pull_request.review_assignments.exists?

      import_requested_reviewer(pull_request, pr_data) || ReviewerSelector.assign!(pull_request)
    end

    def import_requested_reviewer(pull_request, pr_data)
      login = pr_data['requested_reviewers']&.first&.dig('login')
      return nil if login.blank?

      reviewer = Contributor.find_or_create_by!(github_login: login)
      RepositoryContributor.find_or_create_by!(repository: repository, contributor: reviewer)
      ReviewAssignment.create!(pull_request: pull_request, reviewer: reviewer, assigned_at: Time.current)
    end

    def handle_closed(pull_request, pr_data)
      if pr_data['merged']
        pull_request.update!(state: 'merged', merged_at: pr_data['merged_at'])
        record_file_changes(pull_request)
      else
        pull_request.update!(state: 'closed')
      end

      pull_request.review_assignments.where(completed_at: nil).find_each(&:complete!)
    end

    def record_file_changes(pull_request)
      return if pull_request.file_changes.exists?

      files = github_client.pull_request_files(repository.github_full_name, pull_request.github_number)

      files.each { |file| create_file_change(pull_request, file) }
    end

    def create_file_change(pull_request, file)
      FileChange.create!(
        pull_request: pull_request,
        contributor: pull_request.author,
        path: file.filename,
        tech: FileLanguageMapper.tech_for(file.filename),
        lines_changed: file.additions.to_i + file.deletions.to_i
      )
    end

    def find_or_create_pull_request(pr_data, author)
      PullRequest.find_or_create_by!(repository: repository, github_number: pr_data['number']) do |pr|
        pr.author = author
        pr.title = pr_data['title']
        pr.opened_at = pr_data['created_at']
      end
    end

    def github_client
      @github_client ||= Octokit::Client.new(access_token: @access_token)
    end
  end
end
