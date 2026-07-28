# frozen_string_literal: true

# Elige quién debería revisar una PR nueva, combinando dos señales:
#   - carga actual (cuántas revisiones tiene ya asignadas y sin completar)
#   - expertise relevante (cuánto sabe de las tecnologías que toca esta PR concreta)
#
# score = expertise_relevante / (1 + carga_actual)
#
# Dividir por (1 + carga) castiga a quien ya está saturado, aunque sea el
# mayor experto — así no se convierte en el cuello de botella del equipo.
# Sumar 1 evita dividir por cero cuando alguien tiene carga 0.
class ReviewerSelector
  def self.candidates_for(pull_request)
    Contributor
      .joins(:authored_pull_requests)
      .where(pull_requests: { repository_id: pull_request.repository_id })
      .where.not(id: pull_request.author_id)
      .distinct
  end

  # Devuelve los candidatos ordenados de mejor a peor opción, cada uno con su score.
  # top_n: cuántos sugerir (útil para mostrar "2-3 opciones" en vez de forzar 1 nombre).
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

  # Asigna directamente al mejor candidato y crea el ReviewAssignment.
  def self.assign!(pull_request)
    best = rank(pull_request, top_n: 1).first
    return nil unless best

    ReviewAssignment.create!(
      pull_request: pull_request,
      reviewer: best[:contributor],
      assigned_at: Time.current
    )
  end
end
