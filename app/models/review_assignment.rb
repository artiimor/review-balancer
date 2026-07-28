# frozen_string_literal: true

class ReviewAssignment < ApplicationRecord
  belongs_to :pull_request
  belongs_to :reviewer, class_name: 'Contributor'

  validates :assigned_at, presence: true

  def complete!
    update!(completed_at: Time.zone.now) unless completed_at
  end
end
