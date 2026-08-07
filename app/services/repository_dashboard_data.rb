# frozen_string_literal: true

class RepositoryDashboardData
  Bar = Struct.new(:contributor, :pending_reviews, keyword_init: true)
  Cell = Struct.new(:contributor, :tech, :score, :level, keyword_init: true)

  LEVELS = %w[cero bajo medio alto].freeze

  def self.call(repository)
    new(repository).call
  end

  def initialize(repository)
    @repository = repository
  end

  def call
    { pending_reviews: pending_reviews_by_contributor, techs: techs, expertise_rows: expertise_rows }
  end

  private

  attr_reader :repository

  def contributors
    @contributors ||= repository.contributors.order(:github_login).to_a
  end

  def pending_reviews_by_contributor
    contributors.map { |c| Bar.new(contributor: c, pending_reviews: c.current_review_load) }
  end

  def techs
    @techs ||= FileChange.joins(:pull_request)
                         .where(pull_requests: { repository_id: repository.id })
                         .distinct.pluck(:tech).sort
  end

  def expertise_rows
    return [] if contributors.empty? || techs.empty?

    scores_by_contributor = contributors.index_with { |c| ExpertiseCalculator.map_for(c, repository) }
    thresholds = tercile_thresholds(all_scores(scores_by_contributor))

    contributors.map { |contributor| expertise_row(contributor, scores_by_contributor[contributor], thresholds) }
  end

  def all_scores(scores_by_contributor)
    scores_by_contributor.values
                         .flat_map { |scores| techs.map { |tech| scores.fetch(tech, 0.0) } }
                         .select(&:positive?)
  end

  def expertise_row(contributor, scores, thresholds)
    cells = techs.map do |tech|
      score = scores.fetch(tech, 0.0)
      Cell.new(contributor: contributor, tech: tech, score: score, level: level_for(score, thresholds))
    end

    { contributor: contributor, cells: cells }
  end

  def tercile_thresholds(values)
    sorted = values.sort
    return [0, 0] if sorted.uniq.size <= 1

    [percentile(sorted, 33), percentile(sorted, 66)]
  end

  def percentile(sorted, pct)
    return sorted.first if sorted.size == 1

    rank = (pct / 100.0) * (sorted.size - 1)
    lower = sorted[rank.floor]
    upper = sorted[rank.ceil]
    lower + ((upper - lower) * (rank - rank.floor))
  end

  def level_for(score, thresholds)
    low, high = thresholds
    return 'cero' if score <= 0
    return 'bajo' if score <= low
    return 'medio' if score <= high

    'alto'
  end
end
