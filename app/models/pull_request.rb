# frozen_string_literal: true

class PullRequest < ApplicationRecord
  belongs_to :repository
  belongs_to :author, class_name: 'Contributor'
  has_many :review_assignments, dependent: :destroy
  has_many :file_changes, dependent: :destroy

  validates :github_number, presence: true
  validates :opened_at, presence: true

  def merged?
    state == 'merged'
  end
end
