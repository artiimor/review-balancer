# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Github::GithubPullRequestProcessor do
  let(:repository) { create(:repository, provider: 'github') }
  let(:github_access_token) { 'fake_token' }

  describe '.call' do
    context 'when the action is opened' do
      let(:payload) { JSON.parse(file_fixture('github_pull_request_opened.json').read) }
      let(:contributor_login) { payload['pull_request']['user']['login'] }

      before do
        allow_any_instance_of(Octokit::Client).to receive(:pull_request_files).and_return([])
      end

      it 'creates a new contributor if one does not exist' do
        expect(Contributor.find_by(github_login: contributor_login)).to be_nil

        expect do
          described_class.call(repository, payload, github_access_token)
        end.to change(Contributor, :count).by(1)

        expect(Contributor.find_by(github_login: contributor_login)).to be_present
      end

      it 'reuses the contributor if it already exists by github_login' do
        existing_contributor = create(:contributor, github_login: contributor_login)

        expect do
          described_class.call(repository, payload, github_access_token)
        end.not_to change(Contributor, :count)

        pull_request = PullRequest.find_by(github_number: payload['pull_request']['number'], repository: repository)
        expect(pull_request.author).to eq(existing_contributor)
      end

      it 'creates the pull_request with the values from the payload' do
        expect do
          described_class.call(repository, payload, github_access_token)
        end.to change(PullRequest, :count).by(1)

        pull_request = PullRequest.find_by(github_number: payload['pull_request']['number'], repository: repository)
        expect(pull_request.title).to eq(payload['pull_request']['title'])
        expect(pull_request.state).to eq('open')
        expect(pull_request.opened_at).to eq(Time.parse(payload['pull_request']['created_at']))
        expect(pull_request.merged_at).to be_nil
      end

      it 'is idempotent if a pull_request with that repository + github_number already exists' do
        create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)

        expect do
          described_class.call(repository, payload, github_access_token)
        end.not_to change(PullRequest, :count)
      end

      it 'does not assign a reviewer again if the pull_request already has one' do
        pull_request = create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)
        create(:review_assignment, pull_request: pull_request)

        expect(ReviewerSelector).not_to receive(:assign!)

        expect do
          described_class.call(repository, payload, github_access_token)
        end.not_to change(ReviewAssignment, :count)
      end

      it 'calls ReviewerSelector.assign!' do
        expect(ReviewerSelector).to receive(:assign!).with(instance_of(PullRequest))

        described_class.call(repository, payload, github_access_token)
      end

      it 'requests the changed files from the GitHub API' do
        pull_request = create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)
        expect_any_instance_of(Octokit::Client).to receive(:pull_request_files)
          .with(repository.github_full_name, pull_request.github_number).and_return([])

        described_class.call(repository, payload, github_access_token)
      end

      it 'builds the Octokit client with the provided access token' do
        expect(Octokit::Client).to receive(:new).with(access_token: github_access_token).and_call_original

        described_class.call(repository, payload, github_access_token)
      end
    end

    context 'when the PR is opened with a reviewer already requested' do
      let(:payload) { JSON.parse(file_fixture('github_pull_request_opened_with_reviewer.json').read) }
      let(:reviewer_login) { payload['pull_request']['requested_reviewers'].first['login'] }

      before do
        allow_any_instance_of(Octokit::Client).to receive(:pull_request_files).and_return([])
      end

      it 'creates a review_assignment for the already-requested reviewer instead of running the selector' do
        expect(ReviewerSelector).not_to receive(:assign!)

        described_class.call(repository, payload, github_access_token)

        pull_request = PullRequest.find_by(github_number: payload['pull_request']['number'], repository: repository)
        assignment = pull_request.current_review_assignment
        expect(assignment.reviewer.github_login).to eq(reviewer_login)
      end

      it 'creates the reviewer as a contributor if they do not exist yet' do
        expect(Contributor.find_by(github_login: reviewer_login)).to be_nil

        described_class.call(repository, payload, github_access_token)

        expect(Contributor.find_by(github_login: reviewer_login)).to be_present
      end

      it 'links the reviewer to the repository so they show up as a contributor' do
        described_class.call(repository, payload, github_access_token)

        reviewer = Contributor.find_by(github_login: reviewer_login)
        expect(repository.contributors.reload).to include(reviewer)
      end

      it 'does not call the GitHub API to assign a reviewer' do
        expect_any_instance_of(Octokit::Client).not_to receive(:request_pull_request_review)

        described_class.call(repository, payload, github_access_token)
      end
    end

    context 'when a reviewer is manually requested on an already open PR' do
      let(:payload) { JSON.parse(file_fixture('github_pull_request_review_requested.json').read) }
      let(:reviewer_login) { payload['requested_reviewer']['login'] }

      it 'creates a manual review_assignment for the newly requested reviewer' do
        pull_request = create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)
        create(:review_assignment, pull_request: pull_request, completed_at: nil)

        described_class.call(repository, payload, github_access_token)

        assignment = pull_request.reload.current_review_assignment
        expect(assignment.reviewer.github_login).to eq(reviewer_login)
        expect(assignment.source).to eq('manual')
      end

      it 'completes the previous pending review_assignment' do
        pull_request = create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)
        previous_assignment = create(:review_assignment, pull_request: pull_request, completed_at: nil)

        described_class.call(repository, payload, github_access_token)

        expect(previous_assignment.reload.completed_at).not_to be_nil
      end

      it 'links the reviewer to the repository so they show up as a contributor' do
        create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)

        described_class.call(repository, payload, github_access_token)

        reviewer = Contributor.find_by(github_login: reviewer_login)
        expect(repository.contributors.reload).to include(reviewer)
      end
    end

    context 'when the action is closed and the PR was merged' do
      let(:payload) { JSON.parse(file_fixture('github_pull_request_closed_merged.json').read) }
      let(:files) do
        [double(filename: 'app/controllers/users_controller.rb', additions: 10, deletions: 5),
         double(filename: 'app/models/user.rb', additions: 2, deletions: 0)]
      end

      it 'updates the state of the pull_request to "merged" with its merged_at' do
        pull_request = create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)
        allow_any_instance_of(Octokit::Client).to receive(:pull_request_files).and_return([])

        described_class.call(repository, payload, github_access_token)

        pull_request.reload
        expect(pull_request.state).to eq('merged')
        expect(pull_request.merged_at).to eq(Time.parse(payload['pull_request']['merged_at']))
      end

      it 'creates a FileChange for each returned file' do
        pull_request = create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)
        expect_any_instance_of(Octokit::Client).to receive(:pull_request_files)
          .with(repository.github_full_name, pull_request.github_number).and_return(files)

        described_class.call(repository, payload, github_access_token)

        expect(FileChange.count).to eq(2)
      end

      it 'assigns the tech and lines_changed to each FileChange' do
        create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)
        allow_any_instance_of(Octokit::Client).to receive(:pull_request_files).and_return(files)

        described_class.call(repository, payload, github_access_token)

        file_change = FileChange.find_by(path: 'app/controllers/users_controller.rb')
        expect(file_change.tech).to eq(FileLanguageMapper.tech_for(file_change.path))
        expect(file_change.lines_changed).to eq(15)
      end

      it "completes the pull_request's pending review_assignments" do
        pull_request = create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)
        assignment = create(:review_assignment, pull_request: pull_request, completed_at: nil)
        allow_any_instance_of(Octokit::Client).to receive(:pull_request_files).and_return([])

        described_class.call(repository, payload, github_access_token)

        expect(assignment.reload.completed_at).not_to be_nil
      end
    end

    context 'when the action is closed and the PR was not merged' do
      let(:payload) { JSON.parse(file_fixture('github_pull_request_closed_not_merged.json').read) }

      it 'updates the state of the pull_request to "closed"' do
        pull_request = create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)
        expect(pull_request.state).to eq('open')

        described_class.call(repository, payload, github_access_token)

        expect(pull_request.reload.state).to eq('closed')
      end

      it 'does not create file_changes' do
        create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)

        described_class.call(repository, payload, github_access_token)

        expect(FileChange.count).to eq(0)
      end

      it 'does not call the GitHub API' do
        create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)
        expect_any_instance_of(Octokit::Client).not_to receive(:pull_request_files)

        described_class.call(repository, payload, github_access_token)
      end

      it "completes the pull_request's pending review_assignments" do
        pull_request = create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)
        assignment = create(:review_assignment, pull_request: pull_request, completed_at: nil)

        described_class.call(repository, payload, github_access_token)

        expect(assignment.reload.completed_at).not_to be_nil
      end
    end

    context 'when the action is neither opened nor closed' do
      let(:payload) { JSON.parse(file_fixture('github_pull_request_opened.json').read).merge('action' => 'reopened') }

      it 'does nothing beyond creating the contributor and the pull_request' do
        expect(ReviewerSelector).not_to receive(:assign!)

        described_class.call(repository, payload, github_access_token)

        pull_request = PullRequest.find_by(github_number: payload['pull_request']['number'], repository: repository)
        expect(pull_request.state).to eq('open')
      end
    end
  end
end
