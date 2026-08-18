# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Contributors', type: :request do
  let(:user) { create(:user, email: 'user@example.com') }
  let(:other_user) { create(:user, email: 'other@example.com') }
  let(:repository) { create(:repository, user: user) }

  before(:example) { sign_in user }

  describe '#index' do
    it "lists the repository's active contributors" do
      contributor = create(:contributor)
      create(:repository_contributor, repository: repository, contributor: contributor, active: true)

      get repository_contributors_path(repository)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(contributor.github_login)
    end

    it 'also lists inactive contributors' do
      contributor = create(:contributor)
      create(:repository_contributor, repository: repository, contributor: contributor, active: false)

      get repository_contributors_path(repository)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(contributor.github_login)
    end

    it "does not list another repository's contributors" do
      other_repository = create(:repository, user: user)
      own_contributor = create(:contributor)
      other_contributor = create(:contributor)
      repository.contributors << own_contributor
      other_repository.contributors << other_contributor

      get repository_contributors_path(repository)

      expect(response.body).to include(own_contributor.github_login)
      expect(response.body).not_to include(other_contributor.github_login)
    end

    it "does not allow listing another user's repository" do
      other_repository = create(:repository, user: other_user)

      get repository_contributors_path(other_repository)

      expect(response).to have_http_status(:not_found)
    end

    it 'redirects to the sign in page when not authenticated' do
      sign_out user

      get repository_contributors_path(repository)

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe '#update' do
    it "deactivates one of the repository's active contributors" do
      contributor = create(:contributor)
      repository_contributor = create(:repository_contributor, repository: repository, contributor: contributor, active: true)

      patch repository_contributor_path(repository, contributor), params: { contributor: { active: false } }

      expect(response).to redirect_to(repository_contributors_path(repository))
      expect(repository_contributor.reload.active).to eq(false)
    end

    it "reactivates one of the repository's inactive contributors" do
      contributor = create(:contributor)
      repository_contributor = create(:repository_contributor, repository: repository, contributor: contributor, active: false)

      patch repository_contributor_path(repository, contributor), params: { contributor: { active: true } }

      expect(response).to redirect_to(repository_contributors_path(repository))
      expect(repository_contributor.reload.active).to eq(true)
    end

    it 'does not allow updating a contributor that does not belong to the repository' do
      other_repository = create(:repository, user: user)
      contributor = create(:contributor)
      other_repository_contributor = create(:repository_contributor, repository: other_repository, contributor: contributor, active: true)

      patch repository_contributor_path(repository, contributor), params: { contributor: { active: false } }

      expect(response).to have_http_status(:not_found)
      expect(other_repository_contributor.reload.active).to eq(true)
    end

    it "does not allow updating a contributor through another user's repository" do
      other_repository = create(:repository, user: other_user)
      contributor = create(:contributor)
      other_repository_contributor = create(:repository_contributor, repository: other_repository, contributor: contributor, active: true)

      patch repository_contributor_path(other_repository, contributor), params: { contributor: { active: false } }

      expect(response).to have_http_status(:not_found)
      expect(other_repository_contributor.reload.active).to eq(true)
    end

    it 'redirects to the sign in page when not authenticated' do
      contributor = create(:contributor)
      repository.contributors << contributor
      sign_out user

      patch repository_contributor_path(repository, contributor), params: { contributor: { active: false } }

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects with an alert' do
      contributor = create(:contributor)
      create(:repository_contributor, repository: repository, contributor: contributor, active: true)
      allow_any_instance_of(Contributor).to receive(:update).and_return(false)

      patch repository_contributor_path(repository, contributor), params: { contributor: { name: 'New name' } }

      expect(response).to redirect_to(repository_contributors_path(repository))
      expect(flash[:alert]).to eq('No se han podido guardar los cambios del colaborador')
    end
  end
end
