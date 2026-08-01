# frozen_string_literal: true

class PullRequestProcessor
  def self.call(repository_id, payload)
    new(repository_id, payload).call
  end

  def initialize(repository_id, payload)
    @repository_id = repository_id
    @payload = payload
  end

  def call
    if repository_id.blank?
      Rails.logger.error("PullRequestProcessor: repository_id is blank. Payload: #{payload}")
      # TODO add logs with Sentry or papertrail
      return
    end

    if payload.blank?
      Rails.logger.error("PullRequestProcessor: payload is blank. Repository ID: #{repository_id}")
      # TODO add logs with Sentry or papertrail
      return
    end

    repository = Repository.find(repository_id)
    # TODO control de errores cuando faltan estas claves en el payload
    pr_data = payload['pull_request']
    action = payload['action']

    author = find_or_create_contributor(pr_data['user'])
    pull_request = find_or_create_pull_request(repository, pr_data, author)

    case action
    when 'opened'
      handle_opened(pull_request)
    when 'closed'
      handle_closed(pull_request, pr_data, repository)
    end
  end

  private

  attr_reader :repository_id, :payload

  def handle_opened(pull_request)
    assignment = ReviewerSelector.assign!(pull_request)
    # SlackNotifier.notify_review_assigned(assignment) if assignment
  end

  def handle_closed(pull_request, pr_data, repository)
    if pr_data['merged']
      pull_request.update!(state: 'merged', merged_at: pr_data['merged_at'])
      record_file_changes(pull_request, repository)
    else
      pull_request.update!(state: 'closed')
    end

    pull_request.review_assignments.where(completed_at: nil).find_each(&:complete!)
  end

  # GitHub no incluye la lista de archivos tocados en el payload del webhook
  # de pull_request — hay que pedirla aparte a la API REST.
  def record_file_changes(pull_request, repository)
    files = github_client.pull_request_files(
      repository.github_full_name, pull_request.github_number
    )

    files.each do |file|
      FileChange.create!(
        pull_request: pull_request,
        contributor: pull_request.author,
        path: file.filename,
        tech: FileLanguageMapper.tech_for(file.filename),
        lines_changed: file.additions.to_i + file.deletions.to_i
      )
    end
  end

  def find_or_create_contributor(github_user)
    Contributor.find_or_create_by!(github_login: github_user['login'])
  end

  def find_or_create_pull_request(repository, pr_data, author)
    PullRequest.find_or_create_by!(
      repository: repository, github_number: pr_data['number']
    ) do |pr|
      pr.author = author
      pr.title = pr_data['title']
      pr.opened_at = pr_data['created_at']
    end
  end

  def github_client
    @github_client ||= Octokit::Client.new(access_token: ENV.fetch('GITHUB_ACCESS_TOKEN'))
  end
end
