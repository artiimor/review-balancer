# frozen_string_literal: true

class ReviewAssignment < ApplicationRecord
  belongs_to :pull_request
  belongs_to :reviewer, class_name: 'Contributor'

  validates :assigned_at, presence: true
  validates :source, inclusion: { in: %w[auto manual] }

  after_commit :broadcast_pull_request_update

  def complete!
    update!(completed_at: Time.zone.now) unless completed_at
  end

  def review_duration_end
    completed_at || Time.current
  end

  private

  def broadcast_pull_request_update
    fresh_pull_request = pull_request.reload

    fresh_pull_request.broadcast_replace_to(
      fresh_pull_request.repository.pull_requests_stream_name,
      target: fresh_pull_request,
      partial: 'repositories/pull_request',
      locals: { pull_request: fresh_pull_request }
    )
  end
end
