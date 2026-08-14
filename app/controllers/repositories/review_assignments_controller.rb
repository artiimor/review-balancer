# frozen_string_literal: true

module Repositories
  class ReviewAssignmentsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_repository_and_pull_request
    before_action :set_reviewer, only: :create

    def new
      @reviewers = candidate_reviewers
    end

    def create
      begin
        assign_manually
      rescue StandardError => e
        Rails.logger.error("Failed to manually assign reviewer: #{e.message}")
        return render turbo_stream: error_stream
      end

      render turbo_stream: success_stream
    end

    private

    def set_repository_and_pull_request
      @repository = current_user.repositories.find(params[:repository_id])
      @pull_request = @repository.pull_requests.find(params[:pull_request_id])
    end

    def set_reviewer
      return render turbo_stream: success_stream if review_assignment_params[:reviewer_id].blank?

      @reviewer = @repository.contributors.find(review_assignment_params[:reviewer_id])
    end

    def candidate_reviewers
      @repository.active_contributors.order(:github_login).reject { |r| r.id == @pull_request.author_id }
    end

    def assign_manually
      ActiveRecord::Base.transaction do
        previous_reviewers = []
        @pull_request.review_assignments.where(completed_at: nil).find_each do |assignment|
          previous_reviewers << assignment.reviewer
          assignment.complete!
        end

        ReviewAssignment.create!(
          pull_request: @pull_request, reviewer: @reviewer, assigned_at: Time.current, source: 'manual'
        )
        ReviewerSelector.assign_reviewer_remotely(@pull_request, @reviewer, previous_reviewers: previous_reviewers)
      end
    end

    def success_stream
      [turbo_stream.remove('review-assignment-modal-content'), pull_request_replace_stream]
    end

    def pull_request_replace_stream
      turbo_stream.replace(@pull_request, partial: 'repositories/pull_request',
                                          locals: { pull_request: @pull_request.reload })
    end

    def error_stream
      message = t('controllers.repositories.review_assignments.assign_error')

      [
        turbo_stream.remove('review-assignment-modal-content'),
        turbo_stream.update('general_error', partial: 'repositories/error_message', locals: { message: message })
      ]
    end

    def review_assignment_params
      params.require(:review_assignment).permit(:reviewer_id)
    end
  end
end
