# frozen_string_literal: true

class Contributor < ApplicationRecord
  has_many :authored_pull_requests, class_name: 'PullRequest', foreign_key: :author_id, dependent: :nullify
  has_many :review_assignments, foreign_key: :reviewer_id, dependent: :destroy
  has_many :file_changes, dependent: :destroy

  validates :github_login, presence: true, uniqueness: true

  def current_review_load
    review_assignments.where(completed_at: nil).count
  end
end
