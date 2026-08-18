# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Gitlab::GitlabPullRequestProcessor do
  let(:repository) { create(:repository, provider: 'gitlab') }
  let(:pinned_ip) { '93.184.216.34' }

  before do
    allow(SsrfProtection).to receive(:resolve_pinned_ip!).and_return(pinned_ip)
  end

  describe '.call' do
    context 'when the payload is malformed' do
      let(:payload) { JSON.parse(file_fixture('gitlab_merge_request_opened.json').read) }

      it 'logs and raises when object_attributes.iid is missing' do
        payload['object_attributes'].delete('iid')

        expect(Rails.logger).to receive(:error).with(/object_attributes\.iid/)
        expect { described_class.call(repository, payload) }.to raise_error(ActionController::ParameterMissing)
      end

      it 'logs and raises when user.username is missing' do
        payload['user'].delete('username')

        expect(Rails.logger).to receive(:error).with(/user\.username/)
        expect { described_class.call(repository, payload) }.to raise_error(ActionController::ParameterMissing)
      end
    end

    context 'when the action is open' do
      let(:payload) { JSON.parse(file_fixture('gitlab_merge_request_opened.json').read) }
      let(:contributor_login) { payload['user']['username'] }

      before do
        allow(ReviewerSelector).to receive(:assign!)
        no_op_client = instance_double(Gitlab::Client, merge_request_changes: double(changes: []))
        allow(Gitlab).to receive(:client).and_return(no_op_client)
      end

      it 'creates a new contributor if one does not exist' do
        expect(Contributor.find_by(github_login: contributor_login)).to be_nil

        expect do
          described_class.call(repository, payload)
        end.to change(Contributor, :count).by(1)

        expect(Contributor.find_by(github_login: contributor_login)).to be_present
      end

      it 'reuses the contributor if it already exists by github_login' do
        existing_contributor = create(:contributor, github_login: contributor_login)

        expect do
          described_class.call(repository, payload)
        end.not_to change(Contributor, :count)

        pull_request = PullRequest.find_by(github_number: payload['object_attributes']['iid'], repository: repository)
        expect(pull_request.author).to eq(existing_contributor)
      end

      it 'creates the pull_request with the values from the merge request' do
        expect do
          described_class.call(repository, payload)
        end.to change(PullRequest, :count).by(1)

        pull_request = PullRequest.find_by(github_number: payload['object_attributes']['iid'], repository: repository)
        expect(pull_request.title).to eq(payload['object_attributes']['title'])
        expect(pull_request.state).to eq('open')
        expect(pull_request.opened_at).to eq(Time.parse(payload['object_attributes']['created_at']))
        expect(pull_request.merged_at).to be_nil
      end

      it 'is idempotent if a pull_request with that repository + github_number already exists' do
        create(:pull_request, github_number: payload['object_attributes']['iid'], repository: repository)

        expect do
          described_class.call(repository, payload)
        end.not_to change(PullRequest, :count)
      end

      it 'does not assign a reviewer again if the pull_request already has one' do
        pull_request = create(:pull_request, github_number: payload['object_attributes']['iid'], repository: repository)
        create(:review_assignment, pull_request: pull_request)

        expect do
          described_class.call(repository, payload)
        end.not_to change(ReviewAssignment, :count)

        expect(ReviewerSelector).not_to have_received(:assign!)
      end

      it 'calls ReviewerSelector.assign!' do
        described_class.call(repository, payload)

        expect(ReviewerSelector).to have_received(:assign!).with(instance_of(PullRequest))
      end

      it 'requests the changed files from the GitLab API' do
        client = instance_double(Gitlab::Client)
        changes = double(changes: [])
        allow(Gitlab).to receive(:client).and_return(client)
        expect(client).to receive(:merge_request_changes).with(repository.github_full_name, 42).and_return(changes)

        described_class.call(repository, payload)
      end

      it "uses the repository owner's configured GitLab URL when building the client" do
        repository.user.configuration.update!(gitlab_url: 'https://gitlab.example.com')
        client = instance_double(Gitlab::Client, merge_request_changes: double(changes: []))
        expect(Gitlab).to receive(:client)
          .with(
            endpoint: 'https://gitlab.example.com/api/v4', private_token: repository.access_token,
            httparty: {
              connection_adapter: Gitlab::PinnedConnectionAdapter,
              connection_adapter_options: { ssrf_safe_ip: pinned_ip }
            }
          )
          .and_return(client)

        described_class.call(repository, payload)
      end
    end

    context 'when the merge request is opened with a reviewer already requested' do
      let(:payload) { JSON.parse(file_fixture('gitlab_merge_request_opened_with_reviewer.json').read) }
      let(:reviewer_login) { payload['reviewers'].first['username'] }

      before do
        no_op_client = instance_double(Gitlab::Client, merge_request_changes: double(changes: []))
        allow(Gitlab).to receive(:client).and_return(no_op_client)
      end

      it 'creates a review_assignment for the already-requested reviewer instead of running the selector' do
        expect(ReviewerSelector).not_to receive(:assign!)

        described_class.call(repository, payload)

        pull_request = PullRequest.find_by(github_number: payload['object_attributes']['iid'], repository: repository)
        assignment = pull_request.current_review_assignment
        expect(assignment.reviewer.github_login).to eq(reviewer_login)
      end

      it 'creates the reviewer as a contributor if they do not exist yet' do
        expect(Contributor.find_by(github_login: reviewer_login)).to be_nil

        described_class.call(repository, payload)

        expect(Contributor.find_by(github_login: reviewer_login)).to be_present
      end

      it 'links the reviewer to the repository so they show up as a contributor' do
        described_class.call(repository, payload)

        reviewer = Contributor.find_by(github_login: reviewer_login)
        expect(repository.contributors.reload).to include(reviewer)
      end
    end

    context 'when a reviewer is manually changed on an already open merge request' do
      let(:payload) { JSON.parse(file_fixture('gitlab_merge_request_reviewer_updated.json').read) }
      let(:reviewer_login) { payload['reviewers'].first['username'] }

      it 'creates a manual review_assignment for the newly requested reviewer' do
        pull_request = create(:pull_request, github_number: payload['object_attributes']['iid'], repository: repository)
        create(:review_assignment, pull_request: pull_request, completed_at: nil)

        described_class.call(repository, payload)

        assignment = pull_request.reload.current_review_assignment
        expect(assignment.reviewer.github_login).to eq(reviewer_login)
        expect(assignment.source).to eq('manual')
      end

      it 'completes the previous pending review_assignment' do
        pull_request = create(:pull_request, github_number: payload['object_attributes']['iid'], repository: repository)
        previous_assignment = create(:review_assignment, pull_request: pull_request, completed_at: nil)

        described_class.call(repository, payload)

        expect(previous_assignment.reload.completed_at).not_to be_nil
      end

      it 'does nothing when the requested reviewer is already the one assigned (our own remote call echoing back)' do
        pull_request = create(:pull_request, github_number: payload['object_attributes']['iid'], repository: repository)
        same_reviewer = create(:contributor, github_login: reviewer_login)
        existing_assignment = create(:review_assignment, pull_request: pull_request, reviewer: same_reviewer,
                                                         completed_at: nil, source: 'auto')

        expect do
          described_class.call(repository, payload)
        end.not_to change(ReviewAssignment, :count)

        expect(existing_assignment.reload.completed_at).to be_nil
        expect(existing_assignment.reload.source).to eq('auto')
      end
    end

    context 'when the merge request is updated and the GitLab instance omits the changes hash' do
      let(:payload) do
        JSON.parse(file_fixture('gitlab_merge_request_reviewer_updated.json').read).tap { |p| p['changes'] = {} }
      end
      let(:reviewer_login) { payload['reviewers'].first['username'] }

      it 'still reassigns the reviewer, since top-level reviewers is the source of truth' do
        pull_request = create(:pull_request, github_number: payload['object_attributes']['iid'], repository: repository)
        create(:review_assignment, pull_request: pull_request, completed_at: nil)

        described_class.call(repository, payload)

        assignment = pull_request.reload.current_review_assignment
        expect(assignment.reviewer.github_login).to eq(reviewer_login)
      end
    end

    context 'when the action is merge' do
      let(:payload) { JSON.parse(file_fixture('gitlab_merge_request_merged.json').read) }
      let(:changed_file) { double(new_path: 'app/models/user.rb', old_path: nil, diff: "+added\n-removed\n unchanged") }

      before do
        allow(ReviewerSelector).to receive(:assign!)
        client = instance_double(Gitlab::Client)
        allow(Gitlab).to receive(:client).and_return(client)
        allow(client).to receive(:merge_request_changes).and_return(double(changes: [changed_file]))
      end

      it 'sets the state to merged with the updated_at as merged_at' do
        pull_request = create(:pull_request, github_number: payload['object_attributes']['iid'], repository: repository)

        described_class.call(repository, payload)

        pull_request.reload
        expect(pull_request.state).to eq('merged')
        expect(pull_request.merged_at).to eq(Time.parse(payload['object_attributes']['updated_at']))
      end

      it 'records the file changes' do
        create(:pull_request, github_number: payload['object_attributes']['iid'], repository: repository)

        described_class.call(repository, payload)

        expect(FileChange.count).to eq(1)
        expect(FileChange.first.path).to eq('app/models/user.rb')
        expect(FileChange.first.lines_changed).to eq(2)
      end

      it "completes the pull_request's pending review_assignments" do
        pull_request = create(:pull_request, github_number: payload['object_attributes']['iid'], repository: repository)
        assignment = create(:review_assignment, pull_request: pull_request, completed_at: nil)

        described_class.call(repository, payload)

        expect(assignment.reload.completed_at).not_to be_nil
      end
    end

    context 'when the action is close' do
      let(:payload) { JSON.parse(file_fixture('gitlab_merge_request_closed.json').read) }

      it 'sets the state to closed without touching the GitLab API' do
        pull_request = create(:pull_request, github_number: payload['object_attributes']['iid'], repository: repository)
        expect(Gitlab).not_to receive(:client)

        described_class.call(repository, payload)

        expect(pull_request.reload.state).to eq('closed')
      end
    end
  end
end
