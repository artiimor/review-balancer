# frozen_string_literal: true

class PullRequest < ApplicationRecord
  REVIEW_TIME_BUCKETS = {
    'under_1_day' => (0...1.day.to_i),
    '1_to_3_days' => (1.day.to_i...3.days.to_i),
    'over_3_days' => (3.days.to_i...)
  }.freeze

  belongs_to :repository
  belongs_to :author, class_name: 'Contributor'
  has_many :review_assignments, dependent: :destroy
  has_many :file_changes, dependent: :destroy

  validates :github_number, presence: true
  validates :opened_at, presence: true

  after_create :ensure_author_is_repository_contributor

  scope :search_by_query, lambda { |query|
    next all if query.blank?

    sanitized = query.strip
    next where(github_number: sanitized.delete('#')) if sanitized.delete('#') =~ /\A\d+\z/

    where('title ILIKE ?', "%#{sanitized}%")
  }

  scope :with_state, lambda { |states|
    states = Array(states).reject(&:blank?)
    next all if states.empty?

    where(state: states)
  }

  scope :with_reviewer, lambda { |reviewer_ids|
    reviewer_ids = Array(reviewer_ids).reject(&:blank?)
    next all if reviewer_ids.empty?

    joins(:review_assignments).where(review_assignments: { reviewer_id: reviewer_ids }).distinct
  }

  scope :with_review_time, lambda { |bucket|
    range = REVIEW_TIME_BUCKETS[bucket]
    next all if range.nil?

    duration_sql = 'EXTRACT(EPOCH FROM (COALESCE(review_assignments.completed_at, statement_timestamp()) ' \
                   '- review_assignments.assigned_at))'
    relation = joins(:review_assignments).where("#{duration_sql} >= ?", range.begin)
    relation = relation.where("#{duration_sql} < ?", range.end) unless range.end.nil?
    relation.distinct
  }

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
