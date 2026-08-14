# frozen_string_literal: true

class ReviewAssignment < ApplicationRecord
  belongs_to :pull_request
  belongs_to :reviewer, class_name: 'Contributor'

  validates :assigned_at, presence: true
  validates :source, inclusion: { in: %w[auto manual] }

  def complete!
    update!(completed_at: Time.zone.now) unless completed_at
  end

  def review_duration_end
    completed_at || Time.current
  end
end
