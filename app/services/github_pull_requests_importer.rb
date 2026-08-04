# frozen_string_literal: true

class GithubPullRequestsImporter
  LOOKBACK = 1.year

  def self.call(repository, github_access_token)
    new(repository, github_access_token).call
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

  def record_merged_pull_request(pull_request)
    author = Contributor.find_or_create_by!(github_login: pull_request.user.login)

    pull_request = PullRequest.find_or_create_by!(repository: repository, github_number: pull_request.number) do |record|
      record.author = author
      record.title = pull_request.title
      record.opened_at = pull_request.created_at
    end

    pull_request.update!(state: 'merged', merged_at: pull_request.merged_at)

    record_file_changes(pull_request)
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
