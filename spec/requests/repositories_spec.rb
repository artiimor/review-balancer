# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Repositories', type: :request do
  let(:user) { create(:user, email: 'user@example.com') }
  let(:other_user) { create(:user, email: 'other@example.com') }
  let(:headers) { { 'Accept' => 'text/vnd.turbo-stream.html' } }

  before(:example) { sign_in user }

  describe '#index' do
    it 'lists only the current user repositories' do
      my_repository = user.repositories.create!(github_full_name: 'acme/mine', webhook_secret: 's3cr3t')
      other_repository = other_user.repositories.create!(github_full_name: 'acme/other', webhook_secret: 's3cr3t')

      get repositories_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(my_repository.github_full_name)
      expect(response.body).not_to include(other_repository.github_full_name)
    end

    it 'redirects to the sign in page when not authenticated' do
      sign_out user

      get repositories_path

      expect(response).to redirect_to(new_user_session_path)
    end

    context 'when the user does not have a GitHub access token' do
      it 'redirects to the configuration page with an alert' do
        user.configuration.update(github_access_token: nil)

        get repositories_path

        expect(response).to redirect_to(configuration_path)
        expect(flash[:alert]).to eq(I18n.t('controllers.application.github_token_required'))
      end
    end
  end

  describe '#new' do
    it 'renders the modal inside the turbo frame' do
      get new_repository_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="repository-modal"')
      expect(response.body).to include('new_repository')
    end
  end

  describe '#create' do
    let(:valid_params) do
      { repository: { github_full_name: 'acme/new-repo', webhook_secret: 's3cr3t', provider: 'github' } }
    end
    let(:invalid_params) { { repository: { github_full_name: '', webhook_secret: 's3cr3t', provider: 'github' } } }

    context 'with valid params' do
      it 'creates a repository for the current user and closes the modal' do
        expect do
          post repositories_path,
               params: valid_params,
               headers: headers
        end.to change { user.repositories.count }.by(1)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('action="remove"', 'target="new-repository-modal"')
        expect(response.body).to include('action="append"', 'target="repositories"')
        expect(response.body).to include('acme/new-repo')
      end

      it 'enqueues the import jobs with just the repository id, not the access token' do
        post repositories_path,
             params: valid_params,
             headers: headers

        repository = user.repositories.find_by(github_full_name: 'acme/new-repo')

        expect(ImportRepositoryContributorsJob).to have_been_enqueued.with(repository.id)
        expect(ImportRepositoryPullRequestsJob).to have_been_enqueued.with(repository.id)
      end

      context 'when the provider is gitlab' do
        let(:valid_params) do
          { repository: { github_full_name: 'acme/new-gitlab-repo', webhook_secret: 's3cr3t', provider: 'gitlab' } }
        end

        it 'enqueues the import jobs with just the repository id, not the access token' do
          post repositories_path,
               params: valid_params,
               headers: headers

          repository = user.repositories.find_by(github_full_name: 'acme/new-gitlab-repo')

          expect(ImportRepositoryContributorsJob).to have_been_enqueued.with(repository.id)
          expect(ImportRepositoryPullRequestsJob).to have_been_enqueued.with(repository.id)
        end
      end
    end

    context 'with invalid params' do
      it 'does not create a repository and re-renders the modal with the error' do
        expect do
          post repositories_path,
               params: invalid_params,
               headers: headers
        end.not_to change(Repository, :count)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('action="replace"', 'target="new-repository-modal"')
        expect(response.body).to include('no puede estar en blanco')
      end
    end

    context 'when the repository name is already taken' do
      it 'does not create a duplicate' do
        user.repositories.create!(github_full_name: 'acme/existing', webhook_secret: 's3cr3t')

        expect do
          post repositories_path,
               params: { repository: { github_full_name: 'acme/existing', webhook_secret: 'otro' } },
               headers: headers
        end.not_to change(Repository, :count)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('ya está en uso')
      end
    end

    it 'ignores an attempt to assign the repository to another user' do
      post repositories_path,
           params: { repository: { github_full_name: 'acme/other', webhook_secret: 's3cr3t', user_id: other_user.id } },
           headers: headers

      repository = Repository.find_by(github_full_name: 'acme/other')
      expect(repository.user).to eq(user)
    end
  end

  describe '#delete' do
    it "removes the current user's repository" do
      repository = user.repositories.create!(github_full_name: 'acme/to-delete', webhook_secret: 's3cr3t')

      expect do
        delete repository_path(repository), headers: headers
      end.to change(Repository, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('action="remove"')
    end

    it "does not allow deleting another user's repository" do
      other_user = User.create!(email: 'intruder-target@example.com', password: 'password123')
      other_repository = other_user.repositories.create!(github_full_name: 'acme/not-yours', webhook_secret: 's3cr3t')

      expect do
        delete repository_path(other_repository), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      end.not_to change(Repository, :count)

      expect(response).to have_http_status(:not_found)
    end

    it 'shows an error message when the repository cannot be deleted' do
      repository = user.repositories.create!(github_full_name: 'acme/undeletable', webhook_secret: 's3cr3t')
      allow_any_instance_of(Repository).to receive(:destroy).and_return(false)

      expect do
        delete repository_path(repository), headers: headers
      end.not_to change(Repository, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('target="general_error"')
      expect(response.body).to include('No se puede eliminar el repositorio')
    end
  end

  describe '#show' do
    it "renders the repository's pull requests and dashboard data" do
      repository = user.repositories.create!(github_full_name: 'acme/checkout-api', webhook_secret: 's3cr3t')
      contributor = create(:contributor, github_login: 'alice')
      pull_request = create(:pull_request, repository: repository, author: contributor,
                                           title: 'Fix bug', github_number: 42)
      create(:review_assignment, pull_request: pull_request, reviewer: contributor)

      get repository_path(repository)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(repository.github_full_name)
      expect(response.body).to include('#42', 'Fix bug')
      expect(response.body).to include('alice')
    end

    it 'shows the empty state when the repository has no pull requests' do
      repository = user.repositories.create!(github_full_name: 'acme/empty-repo', webhook_secret: 's3cr3t')

      get repository_path(repository)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Todavía no hay pull requests registradas para este repositorio.')
    end

    it "does not allow viewing another user's repository" do
      other_repository = other_user.repositories.create!(github_full_name: 'acme/not-yours', webhook_secret: 's3cr3t')

      get repository_path(other_repository)

      expect(response).to have_http_status(:not_found)
    end

    context 'when the user is not authenticated' do
      it 'redirects to the sign in page' do
        repository = user.repositories.create!(github_full_name: 'acme/checkout-api', webhook_secret: 's3cr3t')
        sign_out user

        get repository_path(repository)

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when the user does not have a GitHub access token' do
      it 'redirects to the configuration page with an alert' do
        repository = user.repositories.create!(github_full_name: 'acme/checkout-api', webhook_secret: 's3cr3t')
        user.configuration.update(github_access_token: nil)

        get repository_path(repository)
        expect(response).to redirect_to(configuration_path)
        expect(flash[:alert]).to eq(I18n.t('controllers.application.github_token_required'))
      end
    end

    context 'with filters' do
      let(:repository) { user.repositories.create!(github_full_name: 'acme/checkout-api', webhook_secret: 's3cr3t') }
      let(:alice) { create(:contributor, github_login: 'alice') }
      let(:bob) { create(:contributor, github_login: 'bob') }

      let!(:matching_pull_request) do
        create(:pull_request, repository: repository, author: bob, title: 'Fix login bug', github_number: 42,
                              state: 'open')
      end
      let!(:other_pull_request) do
        create(:pull_request, repository: repository, author: alice, title: 'Add dashboard', github_number: 7,
                              state: 'merged')
      end
      let!(:third_pull_request) do
        create(:pull_request, repository: repository, author: alice, title: 'Fix signup bug', github_number: 99,
                              state: 'open')
      end

      before do
        create(:review_assignment, pull_request: matching_pull_request, reviewer: alice,
                                   assigned_at: 2.hours.ago)
        create(:review_assignment, pull_request: other_pull_request, reviewer: bob,
                                   assigned_at: 5.days.ago, completed_at: 1.day.ago)
        create(:review_assignment, pull_request: third_pull_request, reviewer: alice,
                                   assigned_at: 3.hours.ago)
      end

      it 'filters by title or PR number' do
        get repository_path(repository, q: 'login')

        expect(response.body).to include('Fix login bug')
        expect(response.body).not_to include('Add dashboard')
        expect(response.body).not_to include('Fix signup bug')
      end

      it 'filters by PR number' do
        get repository_path(repository, q: '#7')

        expect(response.body).to include('Add dashboard')
        expect(response.body).not_to include('Fix login bug')
        expect(response.body).not_to include('Fix signup bug')
      end

      it 'filters by state' do
        get repository_path(repository, state: 'merged')

        expect(response.body).to include('Add dashboard')
        expect(response.body).not_to include('Fix login bug')
        expect(response.body).not_to include('Fix signup bug')
      end

      it 'filters by reviewer' do
        get repository_path(repository, reviewer_id: bob.id)

        expect(response.body).to include('Add dashboard')
        expect(response.body).not_to include('Fix login bug')
        expect(response.body).not_to include('Fix signup bug')
      end

      it 'filters by review time bucket' do
        get repository_path(repository, review_time: 'over_3_days')

        expect(response.body).to include('Add dashboard')
        expect(response.body).not_to include('Fix login bug')
        expect(response.body).not_to include('Fix signup bug')
      end

      it 'returns every matching PR when more than one satisfies the query' do
        get repository_path(repository, q: 'bug')

        expect(response.body).to include('Fix login bug', 'Fix signup bug')
        expect(response.body).not_to include('Add dashboard')
      end

      it 'returns every matching PR when more than one satisfies the state filter' do
        get repository_path(repository, state: 'open')

        expect(response.body).to include('Fix login bug', 'Fix signup bug')
        expect(response.body).not_to include('Add dashboard')
      end

      it 'returns every matching PR when more than one satisfies the reviewer filter' do
        get repository_path(repository, reviewer_id: alice.id)

        expect(response.body).to include('Fix login bug', 'Fix signup bug')
        expect(response.body).not_to include('Add dashboard')
      end

      it 'returns every matching PR when more than one satisfies the review time filter' do
        get repository_path(repository, review_time: 'under_1_day')

        expect(response.body).to include('Fix login bug', 'Fix signup bug')
        expect(response.body).not_to include('Add dashboard')
      end

      it 'shows a filter-specific empty state when nothing matches' do
        get repository_path(repository, q: 'nonexistent-pr-title')

        expect(response.body).to include('No hay pull requests que coincidan con los filtros.')
      end

      it 'selecting several states returns the union of all of them' do
        get repository_path(repository, state: %w[merged open])

        expect(response.body).to include('Fix login bug', 'Fix signup bug', 'Add dashboard')
      end

      it 'selecting several reviewers returns the union of all of them' do
        get repository_path(repository, reviewer_id: [alice.id, bob.id])

        expect(response.body).to include('Fix login bug', 'Fix signup bug', 'Add dashboard')
      end
    end
  end
end
