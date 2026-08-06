# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Github::GithubPullRequestsImporter do
  describe '.call' do
    let(:repository) { create(:repository, github_full_name: 'acme/checkout-api') }
    let!(:github_access_token) { 'fake_token' }

    def github_pr(number:, login: 'alice', title: 'Some PR', created_at: 1.day.ago, merged_at: 1.day.ago)
      double(number: number, user: double(login: login), title: title, created_at: created_at, merged_at: merged_at)
    end

    def github_file(filename:, additions: 3, deletions: 2)
      double(filename: filename, additions: additions, deletions: deletions)
    end

    def stub_pull_requests(*prs)
      allow_any_instance_of(Octokit::Client).to receive(:pull_requests)
        .with(repository.github_full_name, state: 'closed', sort: 'created', direction: 'desc', per_page: 100)
        .and_return(prs)
      allow_any_instance_of(Octokit::Client).to receive(:last_response).and_return(double(rels: {}))
    end

    it 'records a merged pull request and its file changes' do
      stub_pull_requests(github_pr(number: 42))
      allow_any_instance_of(Octokit::Client).to receive(:pull_request_files)
        .with(repository.github_full_name, 42)
        .and_return([github_file(filename: 'app/models/user.rb')])

      described_class.call(repository, github_access_token)

      pull_request = PullRequest.find_by(repository: repository, github_number: 42)
      expect(pull_request).to be_present
      expect(pull_request.state).to eq('merged')
      expect(pull_request.author.github_login).to eq('alice')

      file_change = pull_request.file_changes.sole
      expect(file_change.path).to eq('app/models/user.rb')
      expect(file_change.lines_changed).to eq(5)
      expect(file_change.tech).to eq(FileLanguageMapper.tech_for('app/models/user.rb'))
      expect(file_change.contributor).to eq(pull_request.author)
    end

    it 'ignores pull requests that were closed without being merged' do
      stub_pull_requests(github_pr(number: 7, merged_at: nil))

      expect { described_class.call(repository, github_access_token) }.not_to change(PullRequest, :count)
    end

    it 'stops once it reaches a pull request older than the 1 year lookback' do
      recent = github_pr(number: 1, created_at: 10.days.ago, merged_at: 10.days.ago)
      old = github_pr(number: 2, created_at: 400.days.ago, merged_at: 400.days.ago)
      stub_pull_requests(recent, old)
      allow_any_instance_of(Octokit::Client).to receive(:pull_request_files).and_return([])

      described_class.call(repository, github_access_token)

      expect(PullRequest.where(repository: repository).pluck(:github_number)).to contain_exactly(1)
    end

    it 'reuses an existing Contributor by github_login instead of duplicating it' do
      existing_author = create(:contributor, github_login: 'alice')
      stub_pull_requests(github_pr(number: 5, login: 'alice'))
      allow_any_instance_of(Octokit::Client).to receive(:pull_request_files).and_return([])

      expect { described_class.call(repository, github_access_token) }.not_to change(Contributor, :count)
      expect(PullRequest.find_by(github_number: 5).author).to eq(existing_author)
    end

    it 'does not call the GitHub API for files if they were already recorded' do
      pull_request = create(:pull_request, repository: repository, github_number: 9)
      create(:file_change, pull_request: pull_request)
      stub_pull_requests(github_pr(number: 9, login: pull_request.author.github_login))

      expect_any_instance_of(Octokit::Client).not_to receive(:pull_request_files)

      described_class.call(repository, github_access_token)
    end

    it 'paginates through multiple pages of closed pull requests' do
      next_link = double(href: 'https://api.github.com/repositories/1/pulls?page=2')
      page1 = [github_pr(number: 1)]
      page2 = [github_pr(number: 2)]

      allow_any_instance_of(Octokit::Client).to receive(:pull_requests)
        .with(repository.github_full_name, state: 'closed', sort: 'created', direction: 'desc', per_page: 100)
        .and_return(page1)
      allow_any_instance_of(Octokit::Client).to receive(:get).with(next_link.href).and_return(page2)
      allow_any_instance_of(Octokit::Client).to receive(:last_response).and_return(
        double(rels: { next: next_link }),
        double(rels: {})
      )
      allow_any_instance_of(Octokit::Client).to receive(:pull_request_files).and_return([])

      described_class.call(repository, github_access_token)

      expect(PullRequest.where(repository: repository).pluck(:github_number)).to contain_exactly(1, 2)
    end
  end
end
