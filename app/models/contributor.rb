# frozen_string_literal: true

class Contributor < ApplicationRecord
  has_many :authored_pull_requests,
           class_name: 'PullRequest',
           foreign_key: :author_id,
           dependent: :restrict_with_error
  has_many :review_assignments, foreign_key: :reviewer_id, dependent: :destroy
  has_many :file_changes, dependent: :destroy
  has_many :repository_contributors, dependent: :destroy
  has_many :repositories, through: :repository_contributors
  has_many :holidays, dependent: :destroy

  validates :github_login, presence: true, uniqueness: true

  default_scope { where(active: true) }

  def current_review_load
    review_assignments.where(completed_at: nil).count
  end
end
