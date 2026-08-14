# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Holidays', type: :request do
  let(:user) { create(:user, email: 'user@example.com') }
  let(:other_user) { create(:user, email: 'other@example.com') }
  let(:repository) { create(:repository, user: user) }

  before(:example) { sign_in user }

  describe '#index' do
    it "shows the contributor's name in the title and lists their holidays" do
      contributor = create(:contributor, name: 'Alice Doe', github_login: 'alice')
      repository.contributors << contributor
      create(:holiday, contributor: contributor, start_date: Date.new(2026, 1, 5), end_date: Date.new(2026, 1, 10))

      get repository_contributor_holidays_path(repository, contributor)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Alice Doe')
      expect(response.body).to include('2026-01-05')
      expect(response.body).to include('2026-01-10')
    end

    it 'falls back to the github login when the contributor has no name' do
      contributor = create(:contributor, name: nil, github_login: 'bob')
      repository.contributors << contributor

      get repository_contributor_holidays_path(repository, contributor)

      expect(response.body).to include('bob')
    end

    it 'shows the empty state when the contributor has no holidays' do
      contributor = create(:contributor)
      repository.contributors << contributor

      get repository_contributor_holidays_path(repository, contributor)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Todavía no hay vacaciones registradas para este contributor.')
    end

    it 'also shows holidays for an inactive contributor' do
      contributor = create(:contributor)
      create(:repository_contributor, repository: repository, contributor: contributor, active: false)
      create(:holiday, contributor: contributor)

      get repository_contributor_holidays_path(repository, contributor)

      expect(response).to have_http_status(:ok)
    end

    it 'does not show holidays for a contributor that does not belong to the repository' do
      other_repository = create(:repository, user: user)
      contributor = create(:contributor)
      other_repository.contributors << contributor

      get repository_contributor_holidays_path(repository, contributor)

      expect(response).to have_http_status(:not_found)
    end

    it "does not allow viewing holidays through another user's repository" do
      other_repository = create(:repository, user: other_user)
      contributor = create(:contributor)
      other_repository.contributors << contributor

      get repository_contributor_holidays_path(other_repository, contributor)

      expect(response).to have_http_status(:not_found)
    end

    it 'redirects to the sign in page when not authenticated' do
      contributor = create(:contributor)
      repository.contributors << contributor
      sign_out user

      get repository_contributor_holidays_path(repository, contributor)

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe '#new' do
    it 'renders the modal inside the turbo frame' do
      contributor = create(:contributor)
      repository.contributors << contributor

      get new_repository_contributor_holiday_path(repository, contributor)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="holiday-modal-content"')
      expect(response.body).to include(repository_contributor_holidays_path(repository, contributor))
    end
  end

  describe '#create' do
    let(:contributor) { create(:contributor) }
    let(:headers) { { 'Accept' => 'text/vnd.turbo-stream.html' } }

    before(:example) { repository.contributors << contributor }

    context 'with valid params' do
      let(:valid_params) { { holiday: { start_date: '2026-06-01', end_date: '2026-06-10' } } }

      it 'creates a holiday for the contributor and appends it to the list via turbo stream' do
        expect do
          post repository_contributor_holidays_path(repository, contributor),
               params: valid_params,
               headers: headers
        end.to change { contributor.holidays.count }.by(1)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('action="remove"', 'target="holiday-modal-content"')
        expect(response.body).to include('action="append"', 'target="holidays"')
        expect(response.body).to include('2026-06-01', '2026-06-10')
      end

      it 'removes the empty state row when creating the first holiday' do
        post repository_contributor_holidays_path(repository, contributor),
             params: valid_params,
             headers: headers

        expect(response.body).to include('action="remove"', 'target="no-holidays"')
      end
    end

    context 'with invalid params' do
      let(:invalid_params) { { holiday: { start_date: '', end_date: '2026-06-10' } } }

      it 'does not create a holiday and re-renders the modal with the error' do
        expect do
          post repository_contributor_holidays_path(repository, contributor),
               params: invalid_params,
               headers: headers
        end.not_to change(Holiday, :count)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('action="replace"', 'target="holiday-modal-content"')
        expect(response.body).to include('role="alert"')
      end
    end

    it 'does not allow creating a holiday for a contributor that does not belong to the repository' do
      other_repository = create(:repository, user: user)
      other_contributor = create(:contributor)
      other_repository.contributors << other_contributor

      post repository_contributor_holidays_path(repository, other_contributor),
           params: { holiday: { start_date: '2026-06-01', end_date: '2026-06-10' } },
           headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "does not allow creating a holiday through another user's repository" do
      other_repository = create(:repository, user: other_user)
      other_contributor = create(:contributor)
      other_repository.contributors << other_contributor

      expect do
        post repository_contributor_holidays_path(other_repository, other_contributor),
             params: { holiday: { start_date: '2026-06-01', end_date: '2026-06-10' } },
             headers: headers
      end.not_to change(Holiday, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe '#edit' do
    it 'renders the modal pre-filled for an existing holiday' do
      contributor = create(:contributor)
      repository.contributors << contributor
      holiday = create(:holiday, contributor: contributor,
                                 start_date: Date.new(2026, 1, 5), end_date: Date.new(2026, 1, 10))

      get edit_repository_contributor_holiday_path(repository, contributor, holiday)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="holiday-modal-content"')
      expect(response.body).to include('2026-01-05', '2026-01-10')
      expect(response.body).to include(repository_contributor_holiday_path(repository, contributor, holiday))
    end

    it 'does not allow editing a holiday for a contributor that does not belong to the repository' do
      other_repository = create(:repository, user: user)
      contributor = create(:contributor)
      other_repository.contributors << contributor
      holiday = create(:holiday, contributor: contributor)

      get edit_repository_contributor_holiday_path(repository, contributor, holiday)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe '#update' do
    let(:contributor) { create(:contributor) }
    let(:headers) { { 'Accept' => 'text/vnd.turbo-stream.html' } }
    let(:holiday) do
      create(:holiday, contributor: contributor, start_date: Date.new(2026, 1, 5), end_date: Date.new(2026, 1, 10))
    end

    before(:example) { repository.contributors << contributor }

    context 'with valid params' do
      it 'updates the holiday and replaces its row via turbo stream' do
        patch repository_contributor_holiday_path(repository, contributor, holiday),
              params: { holiday: { start_date: '2026-02-01', end_date: '2026-02-05' } },
              headers: headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('action="remove"', 'target="holiday-modal-content"')
        expect(response.body).to include('action="replace"', "target=\"holiday_#{holiday.id}\"")
        expect(response.body).to include('2026-02-01', '2026-02-05')
        expect(holiday.reload.start_date.to_date).to eq(Date.new(2026, 2, 1))
      end
    end

    context 'with invalid params' do
      it 'does not update the holiday and re-renders the modal with the error' do
        patch repository_contributor_holiday_path(repository, contributor, holiday),
              params: { holiday: { start_date: '', end_date: '2026-02-05' } },
              headers: headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('action="replace"', 'target="holiday-modal-content"')
        expect(response.body).to include('role="alert"')
        expect(holiday.reload.start_date.to_date).to eq(Date.new(2026, 1, 5))
      end
    end

    it 'does not allow updating a holiday for a contributor that does not belong to the repository' do
      other_repository = create(:repository, user: user)
      other_contributor = create(:contributor)
      other_repository.contributors << other_contributor
      other_holiday = create(:holiday, contributor: other_contributor)

      patch repository_contributor_holiday_path(repository, other_contributor, other_holiday),
            params: { holiday: { start_date: '2026-02-01', end_date: '2026-02-05' } },
            headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "does not allow updating a holiday through another user's repository" do
      other_repository = create(:repository, user: other_user)
      other_contributor = create(:contributor)
      other_repository.contributors << other_contributor
      other_holiday = create(:holiday, contributor: other_contributor,
                                       start_date: Date.new(2026, 1, 5), end_date: Date.new(2026, 1, 10))

      patch repository_contributor_holiday_path(other_repository, other_contributor, other_holiday),
            params: { holiday: { start_date: '2026-02-01', end_date: '2026-02-05' } },
            headers: headers

      expect(response).to have_http_status(:not_found)
      expect(other_holiday.reload.start_date.to_date).to eq(Date.new(2026, 1, 5))
    end
  end

  describe '#destroy' do
    let(:contributor) { create(:contributor) }
    let(:headers) { { 'Accept' => 'text/vnd.turbo-stream.html' } }

    before(:example) { repository.contributors << contributor }

    it 'destroys the holiday and removes its row via turbo stream' do
      holiday = create(:holiday, contributor: contributor)

      expect do
        delete repository_contributor_holiday_path(repository, contributor, holiday), headers: headers
      end.to change { contributor.holidays.count }.by(-1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('action="remove"', "target=\"holiday_#{holiday.id}\"")
    end

    it 'brings back the empty state row when the last holiday is destroyed' do
      holiday = create(:holiday, contributor: contributor)

      delete repository_contributor_holiday_path(repository, contributor, holiday), headers: headers

      expect(response.body).to include('action="append"', 'target="holidays"')
      expect(response.body).to include('id="no-holidays"')
    end

    it 'does not bring back the empty state row when other holidays remain' do
      holiday = create(:holiday, contributor: contributor)
      create(:holiday, contributor: contributor)

      delete repository_contributor_holiday_path(repository, contributor, holiday), headers: headers

      expect(response.body).not_to include('id="no-holidays"')
    end

    it 'does not allow destroying a holiday for a contributor that does not belong to the repository' do
      other_repository = create(:repository, user: user)
      other_contributor = create(:contributor)
      other_repository.contributors << other_contributor
      other_holiday = create(:holiday, contributor: other_contributor)

      expect do
        delete repository_contributor_holiday_path(repository, other_contributor, other_holiday), headers: headers
      end.not_to change(Holiday, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "does not allow destroying a holiday through another user's repository" do
      other_repository = create(:repository, user: other_user)
      other_contributor = create(:contributor)
      other_repository.contributors << other_contributor
      other_holiday = create(:holiday, contributor: other_contributor)

      expect do
        delete repository_contributor_holiday_path(other_repository, other_contributor, other_holiday),
               headers: headers
      end.not_to change(Holiday, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
