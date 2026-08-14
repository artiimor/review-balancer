# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ReviewAssignments', type: :request do
  let(:user) { create(:user, email: 'user@example.com') }
  let(:other_user) { create(:user, email: 'other@example.com') }
  let(:repository) { create(:repository, user: user) }
  let(:pull_request) { create(:pull_request, repository: repository) }
  let(:reviewer) { create(:contributor, github_login: 'chosen_reviewer') }
  let(:headers) { { 'Accept' => 'text/vnd.turbo-stream.html' } }

  before(:example) do
    sign_in user
    repository.contributors << reviewer
  end

  describe '#new' do
    it 'renders the modal inside the turbo frame with the candidate reviewers' do
      get new_repository_pull_request_review_assignment_path(repository, pull_request)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="review-assignment-modal"')
      expect(response.body).to include('chosen_reviewer')
      expect(response.body).to include(repository_pull_request_review_assignments_path(repository, pull_request))
    end

    it 'excludes the pull_request author from the candidate reviewers' do
      get new_repository_pull_request_review_assignment_path(repository, pull_request)

      expect(response.body).not_to include(pull_request.author.github_login)
    end

    it 'does not allow opening the modal through another user\'s repository' do
      other_repository = create(:repository, user: other_user)
      other_pull_request = create(:pull_request, repository: other_repository)

      get new_repository_pull_request_review_assignment_path(other_repository, other_pull_request)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe '#create' do
    context 'when the remote assignment succeeds' do
      before do
        allow(ReviewerSelector).to receive(:assign_reviewer_remotely)
      end

      it 'closes the previous pending assignment and creates a manual one for the chosen reviewer' do
        previous_assignment = create(:review_assignment, pull_request: pull_request, completed_at: nil)

        post repository_pull_request_review_assignments_path(repository, pull_request),
             params: { review_assignment: { reviewer_id: reviewer.id } },
             headers: headers

        expect(response).to have_http_status(:ok)
        expect(previous_assignment.reload.completed_at).not_to be_nil

        assignment = pull_request.reload.current_review_assignment
        expect(assignment.reviewer).to eq(reviewer)
        expect(assignment.source).to eq('manual')
      end

      it 'requests the review from the provider' do
        expect(ReviewerSelector).to receive(:assign_reviewer_remotely)
          .with(pull_request, reviewer, previous_reviewers: [])

        post repository_pull_request_review_assignments_path(repository, pull_request),
             params: { review_assignment: { reviewer_id: reviewer.id } },
             headers: headers
      end

      it 'passes the previously assigned reviewer along, so it can be removed from the provider' do
        previous_assignment = create(:review_assignment, pull_request: pull_request, completed_at: nil)

        expect(ReviewerSelector).to receive(:assign_reviewer_remotely)
          .with(pull_request, reviewer, previous_reviewers: [previous_assignment.reviewer])

        post repository_pull_request_review_assignments_path(repository, pull_request),
             params: { review_assignment: { reviewer_id: reviewer.id } },
             headers: headers
      end

      it 'closes the modal and replaces the pull_request row via turbo stream' do
        post repository_pull_request_review_assignments_path(repository, pull_request),
             params: { review_assignment: { reviewer_id: reviewer.id } },
             headers: headers

        expect(response.body).to include('action="remove"', 'target="review-assignment-modal-content"')
        expect(response.body).to include('action="replace"', "target=\"pull_request_#{pull_request.id}\"")
        expect(response.body).to include('chosen_reviewer')
      end

      it 'never removes the review-assignment-modal turbo frame itself, so it can be reopened later' do
        post repository_pull_request_review_assignments_path(repository, pull_request),
             params: { review_assignment: { reviewer_id: reviewer.id } },
             headers: headers

        expect(response.body).not_to include('target="review-assignment-modal"')
      end

      it 'allows reassigning again right after a first successful reassignment' do
        other_reviewer = create(:contributor, github_login: 'second_reviewer')
        repository.contributors << other_reviewer

        post repository_pull_request_review_assignments_path(repository, pull_request),
             params: { review_assignment: { reviewer_id: reviewer.id } },
             headers: headers

        post repository_pull_request_review_assignments_path(repository, pull_request),
             params: { review_assignment: { reviewer_id: other_reviewer.id } },
             headers: headers

        expect(response).to have_http_status(:ok)
        expect(pull_request.reload.current_review_assignment.reviewer).to eq(other_reviewer)
      end
    end

    context 'when the remote assignment fails' do
      before do
        allow(ReviewerSelector).to receive(:assign_reviewer_remotely).and_raise(StandardError, 'boom')
      end

      it 'rolls back the review_assignment, closes the modal and shows an error, without touching the previous one' do
        previous_assignment = create(:review_assignment, pull_request: pull_request, completed_at: nil)

        expect do
          post repository_pull_request_review_assignments_path(repository, pull_request),
               params: { review_assignment: { reviewer_id: reviewer.id } },
               headers: headers
        end.not_to change(ReviewAssignment, :count)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('action="remove"', 'target="review-assignment-modal-content"')
        expect(response.body).to include('role="alert"')
        expect(previous_assignment.reload.completed_at).to be_nil
      end
    end

    it "does not allow assigning a reviewer through another user's repository" do
      other_repository = create(:repository, user: other_user)
      other_pull_request = create(:pull_request, repository: other_repository)
      other_repository.contributors << reviewer

      post repository_pull_request_review_assignments_path(other_repository, other_pull_request),
           params: { review_assignment: { reviewer_id: reviewer.id } },
           headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'does nothing and re-renders the row when the placeholder option is submitted with a blank reviewer_id' do
      previous_assignment = create(:review_assignment, pull_request: pull_request, completed_at: nil)

      expect do
        post repository_pull_request_review_assignments_path(repository, pull_request),
             params: { review_assignment: { reviewer_id: '' } },
             headers: headers
      end.not_to change(ReviewAssignment, :count)

      expect(response).to have_http_status(:ok)
      expect(previous_assignment.reload.completed_at).to be_nil
    end

    it 'does not allow assigning a reviewer that does not belong to the repository' do
      outsider = create(:contributor, github_login: 'outsider')

      post repository_pull_request_review_assignments_path(repository, pull_request),
           params: { review_assignment: { reviewer_id: outsider.id } },
           headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'redirects to the sign in page when not authenticated' do
      sign_out user

      post repository_pull_request_review_assignments_path(repository, pull_request),
           params: { review_assignment: { reviewer_id: reviewer.id } },
           headers: headers

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
