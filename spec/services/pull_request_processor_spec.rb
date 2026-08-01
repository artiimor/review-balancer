# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PullRequestProcessor do
  let(:repository) { create(:repository) }

  describe '.call' do
    context 'when repository_id is blank' do
      it 'logs an error and returns early' do
        expect(Rails.logger).to receive(:error).with(/repository_id is blank/)
        described_class.call(nil, { 'pull_request' => {}, 'action' => 'opened' })
      end
    end

    context 'when payload is blank' do
      it 'logs an error and returns early' do
        expect(Rails.logger).to receive(:error).with(/payload is blank/)
        described_class.call(repository.id, nil)
      end
    end

    context 'when action is opened' do
      let(:payload) { JSON.parse(file_fixture('github_pull_request_opened.json').read) }
      let(:contributor_login) { payload['pull_request']['user']['login'] }

      it 'creates a new contributor if one does not exist' do
        contributor = Contributor.find_by(github_login: contributor_login)
        expect(contributor).to be_nil
        
        expect { described_class.call(repository.id, payload) }.to change(Contributor, :count).by(1)
        
        contributor = Contributor.find_by(github_login: contributor_login)
        expect(contributor).to be_present
      end

      it 'reutilizes the contributor if it already exists by github_login' do
        existing_contributor = create(:contributor, github_login: contributor_login)
        expect { described_class.call(repository.id, payload) }.not_to change(Contributor, :count)
        
        contributor = Contributor.find_by(github_login: contributor_login)
        expect(contributor).to eq(existing_contributor)
      end
      
      it 'creates the pull_request if it does not exist' do
        pull_request = PullRequest.find_by(github_number: payload['pull_request']['number'], repository: repository)
        expect(pull_request).to be_nil

        expect { described_class.call(repository.id, payload) }.to change(PullRequest, :count).by(1)
        
        pull_request = PullRequest.find_by(github_number: payload['pull_request']['number'], repository: repository)
        expect(pull_request).to be_present
      end
      
      it 'is idempotent if a pull_request with that repository_id + github_number already exists' do
        existing_pull_request = create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)
        expect { described_class.call(repository.id, payload) }.not_to change(PullRequest, :count)
      end
      
      it 'calls ReviewerSelector.assign!' do
        expect(ReviewerSelector).to receive(:assign!).with(instance_of(PullRequest))
        described_class.call(repository.id, payload)
      end

      it 'assigns correct values to the pull_request' do
        described_class.call(repository.id, payload)
        pull_request = PullRequest.find_by(github_number: payload['pull_request']['number'], repository: repository)

        expect(pull_request.title).to eq(payload['pull_request']['title'])
        expect(pull_request.author.github_login).to eq(payload['pull_request']['user']['login'])
        expect(pull_request.state).to eq('open')
        expect(pull_request.opened_at).to eq(Time.parse(payload['pull_request']['created_at']))
        expect(pull_request.merged_at).to be_nil
      end
    end

    context 'when action is closed and the PR was merged' do
      let(:payload) { JSON.parse(file_fixture('github_pull_request_closed_merged.json').read) }
      let(:files) { [ double(filename: 'app/controllers/users_controller.rb', additions: 10, deletions: 5),
                      double(filename: 'app/models/user.rb', additions: 2, deletions: 0) ] }

      it 'updates the state of the pull_request to "merged" with its merged_at' do
        pull_request = create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)
        expect(pull_request.state).to eq('open')
        expect(pull_request.merged_at).to be_nil

        allow_any_instance_of(Octokit::Client).to receive(:pull_request_files).and_return([])
        described_class.call(repository.id, payload)

        pull_request.reload
        expect(pull_request.state).to eq('merged')
        expect(pull_request.merged_at).to eq(Time.parse(payload['pull_request']['merged_at']))
      end

      it 'requests the changed files from the GitHub API' do
        pull_request = create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)
        expect_any_instance_of(Octokit::Client).to receive(:pull_request_files).with(repository.github_full_name, pull_request.github_number).and_return([])

        described_class.call(repository.id, payload)
      end

      it 'creates a FileChange for each returned file' do
        pull_request = create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)
        expect_any_instance_of(Octokit::Client).to receive(:pull_request_files).with(repository.github_full_name, pull_request.github_number).and_return(files)

        described_class.call(repository.id, payload)

        expect(FileChange.count).to eq(2)
      end

      it 'assigns the tech to each FileChange via FileLanguageMapper' do
        pull_request = create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)
        expect_any_instance_of(Octokit::Client).to receive(:pull_request_files).with(repository.github_full_name, pull_request.github_number).and_return(files)

        described_class.call(repository.id, payload)

        expect(FileChange.first.tech).to eq(FileLanguageMapper.tech_for(files.first.filename))
      end
    end

    context 'when action is closed and the PR was not merged' do
      let(:payload) { JSON.parse(file_fixture('github_pull_request_closed_not_merged.json').read) }

      it 'actualiza el estado de la pull_request a "closed"' do
        pull_request = create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)
        expect(pull_request.state).to eq('open')

        described_class.call(repository.id, payload)

        pull_request.reload
        expect(pull_request.state).to eq('closed')
      end

      it 'no crea file_changes' do
        pull_request = create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)
        allow_any_instance_of(Octokit::Client).to receive(:pull_request_files).and_return([])

        described_class.call(repository.id, payload)

        expect(FileChange.count).to eq(0)
      end

      it 'no llama a la API de GitHub' do
        pull_request = create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)
        expect_any_instance_of(Octokit::Client).not_to receive(:pull_request_files)

        described_class.call(repository.id, payload)
      end

      it 'completa los review_assignments pendientes de la pull_request' do
        pull_request = create(:pull_request, github_number: payload['pull_request']['number'], repository: repository)
        assignment = create(:review_assignment, pull_request: pull_request, completed_at: nil)

        described_class.call(repository.id, payload)

        assignment.reload
        expect(assignment.completed_at).not_to be_nil
      end
    end

    context 'when the action is neither opened nor closed' do
      let(:payload) { JSON.parse(file_fixture('github_pull_request_opened.json').read).merge('action' => 'reopened') }

      it 'does nothing beyond creating the contributor and the pull_request' do
        expect(ReviewerSelector).not_to receive(:assign!)

        described_class.call(repository.id, payload)

        pull_request = PullRequest.find_by(github_number: payload['pull_request']['number'], repository: repository)
        expect(pull_request.state).to eq('open')
      end
    end
  end
end
