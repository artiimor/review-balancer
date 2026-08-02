# frozen_string_literal: true

class ExpertiseCalculator
  HALF_LIFE_DAYS = 90.0
  DECAY_RATE = Math.log(2) / HALF_LIFE_DAYS

  def self.map_for(contributor, repository, as_of: Time.current)
    changes = FileChange
              .joins(:pull_request)
              .where(contributor: contributor)
              .where(pull_requests: { repository_id: repository.id })
              .where.not(pull_requests: { merged_at: nil })
              .pluck(:tech, :lines_changed, 'pull_requests.merged_at')

    scores = Hash.new(0.0)

    changes.each do |tech, lines_changed, merged_at|
      days_ago = (as_of - merged_at) / 1.day
      decay = Math.exp(-DECAY_RATE * days_ago)
      scores[tech] += lines_changed * decay
    end

    scores.sort_by { |_tech, score| -score }.to_h
  end

  def self.score_for_techs(contributor, techs, repository, as_of: Time.current)
    full_map = map_for(contributor, repository, as_of: as_of)
    techs.sum { |tech| full_map.fetch(tech, 0.0) }
  end
end
