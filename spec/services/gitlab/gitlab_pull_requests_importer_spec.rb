# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Gitlab::GitlabPullRequestsImporter do
  describe '.call' do
    let(:repository) { create(:repository, github_full_name: 'acme/checkout-api', provider: 'gitlab') }

    def gitlab_mr(iid:, username: 'alice', created_at: 1.day.ago, merged_at: 1.day.ago, reviewers: [])
      double(iid: iid, author: double(username: username), title: 'Some MR', created_at: created_at,
             merged_at: merged_at, reviewers: reviewers)
    end

    def gitlab_file(path:, diff: "+++ b/#{path}\n--- a/#{path}\n+line1\n+line2\n-line3\n")
      double(new_path: path, old_path: path, diff: diff)
    end

    def gitlab_reviewer(username:)
      double(username: username)
    end

    def stub_merge_requests(mrs, page: 1)
      allow_any_instance_of(Gitlab::Client).to receive(:merge_requests)
        .with(repository.github_full_name,
              state: 'merged', order_by: 'created_at', sort: 'desc', per_page: 100, page: page)
        .and_return(mrs)
    end

    it 'records a merged pull request and its file changes' do
      stub_merge_requests([gitlab_mr(iid: 42)])
      stub_merge_requests([], page: 2)
      allow_any_instance_of(Gitlab::Client).to receive(:merge_request_changes)
        .with(repository.github_full_name, 42)
        .and_return(double(changes: [gitlab_file(path: 'app/models/user.rb')]))

      described_class.call(repository)

      pull_request = PullRequest.find_by(repository: repository, github_number: 42)
      expect(pull_request).to be_present
      expect(pull_request.state).to eq('merged')
      expect(pull_request.author.github_login).to eq('alice')

      file_change = pull_request.file_changes.sole
      expect(file_change.path).to eq('app/models/user.rb')
      expect(file_change.lines_changed).to eq(3)
      expect(file_change.tech).to eq(FileLanguageMapper.tech_for('app/models/user.rb'))
      expect(file_change.contributor).to eq(pull_request.author)
    end

    it 'ignores merge requests without a merged_at timestamp' do
      stub_merge_requests([gitlab_mr(iid: 7, merged_at: nil)])
      stub_merge_requests([], page: 2)

      expect { described_class.call(repository) }.not_to change(PullRequest, :count)
    end

    it 'imports the requested reviewer when the merge request already has one' do
      stub_merge_requests([gitlab_mr(iid: 42, reviewers: [gitlab_reviewer(username: 'bob')])])
      stub_merge_requests([], page: 2)
      allow_any_instance_of(Gitlab::Client).to receive(:merge_request_changes).and_return(double(changes: []))

      described_class.call(repository)

      pull_request = PullRequest.find_by(repository: repository, github_number: 42)
      assignment = pull_request.current_review_assignment
      expect(assignment.reviewer.github_login).to eq('bob')
      expect(assignment.completed_at).to be_present
    end

    it 'links the imported reviewer to the repository' do
      stub_merge_requests([gitlab_mr(iid: 42, reviewers: [gitlab_reviewer(username: 'bob')])])
      stub_merge_requests([], page: 2)
      allow_any_instance_of(Gitlab::Client).to receive(:merge_request_changes).and_return(double(changes: []))

      described_class.call(repository)

      expect(repository.contributors.reload.map(&:github_login)).to include('bob')
    end

    it 'does not create a review_assignment when the merge request has no reviewers' do
      stub_merge_requests([gitlab_mr(iid: 42)])
      stub_merge_requests([], page: 2)
      allow_any_instance_of(Gitlab::Client).to receive(:merge_request_changes).and_return(double(changes: []))

      described_class.call(repository)

      pull_request = PullRequest.find_by(repository: repository, github_number: 42)
      expect(pull_request.review_assignments).to be_empty
    end

    it 'does not import a reviewer again if the pull request already has one' do
      pull_request = create(:pull_request, repository: repository, github_number: 42)
      create(:review_assignment, pull_request: pull_request)
      stub_merge_requests([gitlab_mr(iid: 42, username: pull_request.author.github_login,
                                     reviewers: [gitlab_reviewer(username: 'someone_else')])])
      stub_merge_requests([], page: 2)
      allow_any_instance_of(Gitlab::Client).to receive(:merge_request_changes).and_return(double(changes: []))

      expect { described_class.call(repository) }.not_to change(ReviewAssignment, :count)
    end

    it 'stops once it reaches a merge request older than the 1 year lookback' do
      recent = gitlab_mr(iid: 1, created_at: 10.days.ago, merged_at: 10.days.ago)
      old = gitlab_mr(iid: 2, created_at: 400.days.ago, merged_at: 400.days.ago)
      stub_merge_requests([recent, old])
      allow_any_instance_of(Gitlab::Client).to receive(:merge_request_changes).and_return(double(changes: []))

      described_class.call(repository)

      expect(PullRequest.where(repository: repository).pluck(:github_number)).to contain_exactly(1)
    end

    it 'reuses an existing Contributor by github_login instead of duplicating it' do
      existing_author = create(:contributor, github_login: 'alice')
      stub_merge_requests([gitlab_mr(iid: 5, username: 'alice')])
      stub_merge_requests([], page: 2)
      allow_any_instance_of(Gitlab::Client).to receive(:merge_request_changes).and_return(double(changes: []))

      expect { described_class.call(repository) }.not_to change(Contributor, :count)
      expect(PullRequest.find_by(github_number: 5).author).to eq(existing_author)
    end

    it 'does not call the GitLab API for files if they were already recorded' do
      pull_request = create(:pull_request, repository: repository, github_number: 9)
      create(:file_change, pull_request: pull_request)
      stub_merge_requests([gitlab_mr(iid: 9, username: pull_request.author.github_login)])
      stub_merge_requests([], page: 2)

      expect_any_instance_of(Gitlab::Client).not_to receive(:merge_request_changes)

      described_class.call(repository)
    end

    it 'paginates through multiple pages of merged merge requests' do
      stub_merge_requests([gitlab_mr(iid: 1)], page: 1)
      stub_merge_requests([gitlab_mr(iid: 2)], page: 2)
      stub_merge_requests([], page: 3)
      allow_any_instance_of(Gitlab::Client).to receive(:merge_request_changes).and_return(double(changes: []))

      described_class.call(repository)

      expect(PullRequest.where(repository: repository).pluck(:github_number)).to contain_exactly(1, 2)
    end

    it 'stops once it reaches a merge request older than the given lookback' do
      recent = gitlab_mr(iid: 1, created_at: 100.days.ago, merged_at: 100.days.ago)
      old = gitlab_mr(iid: 2, created_at: 200.days.ago, merged_at: 200.days.ago)
      stub_merge_requests([recent, old])
      allow_any_instance_of(Gitlab::Client).to receive(:merge_request_changes).and_return(double(changes: []))

      described_class.call(repository, lookback: 6.months)

      expect(PullRequest.where(repository: repository).pluck(:github_number)).to contain_exactly(1)
    end

    it "uses the repository owner's configured GitLab URL when building the client" do
      repository.user.configuration.update!(gitlab_url: 'https://gitlab.example.com')
      client = instance_double(Gitlab::Client, merge_requests: [])
      expect(Gitlab).to receive(:client)
        .with(endpoint: 'https://gitlab.example.com/api/v4', private_token: repository.access_token)
        .and_return(client)

      described_class.call(repository)
    end

    it 'defaults to gitlab.com when no GitLab URL is configured' do
      client = instance_double(Gitlab::Client, merge_requests: [])
      expect(Gitlab).to receive(:client)
        .with(endpoint: 'https://gitlab.com/api/v4', private_token: repository.access_token)
        .and_return(client)

      described_class.call(repository)
    end
  end
end
