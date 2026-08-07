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
        expect(flash[:alert]).to eq(I18n.t('configuration.github_token_required'))
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
    let(:valid_params) { { repository: { github_full_name: 'acme/new-repo', webhook_secret: 's3cr3t', provider: 'github' } } }
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

      it 'enqueues the import jobs with the repository id and the github access token' do
        post repositories_path,
             params: valid_params,
             headers: headers

        repository = user.repositories.find_by(github_full_name: 'acme/new-repo')

        expect(ImportRepositoryContributorsJob).to have_been_enqueued
          .with(repository.id, user.configuration.github_access_token)
        expect(ImportRepositoryPullRequestsJob).to have_been_enqueued
          .with(repository.id, user.configuration.github_access_token)
      end

      context 'when the provider is gitlab' do
        let(:valid_params) do
          { repository: { github_full_name: 'acme/new-gitlab-repo', webhook_secret: 's3cr3t', provider: 'gitlab' } }
        end

        it 'enqueues the import jobs with the repository id and the gitlab access token' do
          post repositories_path,
               params: valid_params,
               headers: headers

          repository = user.repositories.find_by(github_full_name: 'acme/new-gitlab-repo')

          expect(ImportRepositoryContributorsJob).to have_been_enqueued
            .with(repository.id, user.configuration.gitlab_access_token)
          expect(ImportRepositoryPullRequestsJob).to have_been_enqueued
            .with(repository.id, user.configuration.gitlab_access_token)
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
        expect(response.body).to include("can&#39;t be blank")
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
        expect(response.body).to include('has already been taken')
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
        expect(flash[:alert]).to eq(I18n.t('configuration.github_token_required'))
      end
    end
  end
end
