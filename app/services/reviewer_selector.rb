# frozen_string_literal: true

class ReviewerSelector
  def self.candidates_for(pull_request)
    pull_request.repository.contributors.where.not(id: pull_request.author_id)
  end

  def self.rank(pull_request, top_n: 3)
    techs = pull_request.file_changes.pluck(:tech).uniq
    candidates = candidates_for(pull_request)

    ranked = candidates.map do |contributor|
      expertise = ExpertiseCalculator.score_for_techs(contributor, techs)
      load_ = contributor.current_review_load
      score = expertise / (1 + load_)

      { contributor: contributor, expertise: expertise, load: load_, score: score }
    end

    ranked.sort_by { |entry| -entry[:score] }.first(top_n)
  end

  def self.assign!(pull_request)
    best = rank(pull_request, top_n: 1).first
    return nil unless best

    assignment = ReviewAssignment.create!(
      pull_request: pull_request,
      reviewer: best[:contributor],
      assigned_at: Time.current,
      matched_tech: matched_tech_for(pull_request, best[:contributor])
    )
    assignment.complete! unless pull_request.state == 'open'

    assignment
  end

  def self.matched_tech_for(pull_request, contributor)
    techs = pull_request.file_changes.pluck(:tech).uniq
    scores = ExpertiseCalculator.map_for(contributor).slice(*techs)
    top_tech, top_score = scores.max_by { |_tech, score| score }

    top_tech if top_score&.positive?
  end
end
