# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Repositories', type: :request do
  let(:user) { User.create!(email: 'user@example.com', password: 'password123') }
  let(:other_user) { User.create!(email: 'other@example.com', password: 'password123') }
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
    let(:valid_params) { { repository: { github_full_name: 'acme/new-repo', webhook_secret: 's3cr3t' } } }
    let(:invalid_params) { { repository: { github_full_name: '', webhook_secret: 's3cr3t' } } }

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
  end
end
