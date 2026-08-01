# frozen_string_literal: true

class PullRequest < ApplicationRecord
  belongs_to :repository
  belongs_to :author, class_name: 'Contributor'
  has_many :review_assignments, dependent: :destroy
  has_many :file_changes, dependent: :destroy

  validates :github_number, presence: true
  validates :opened_at, presence: true

  after_create :ensure_author_is_repository_contributor

  def merged?
    state == 'merged'
  end

  def current_review_assignment
    review_assignments.max_by(&:assigned_at)
  end

  private

  def ensure_author_is_repository_contributor
    RepositoryContributor.find_or_create_by!(repository: repository, contributor: author)
  end
end
