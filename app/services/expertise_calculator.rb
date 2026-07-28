# frozen_string_literal: true

# Calcula, para un contribuidor, en qué tecnologías tiene más "expertise"
# reciente. En vez de mantener un contador que hay que ir decayendo con jobs
# periódicos, guardamos la señal cruda (FileChange, con su fecha vía la PR)
# y calculamos el decaimiento en el momento de la consulta. Es más simple y
# no puede desincronizarse.
#
# Fórmula: cada línea cambiada pesa `lines_changed`, pero se multiplica por un
# factor que decae exponencialmente con el tiempo desde que se mergeó la PR,
# con una vida media (HALF_LIFE_DAYS) configurable. Así el trabajo de hace
# 2 semanas pesa mucho más que el de hace 8 meses, sin necesidad de borrar nada.
class ExpertiseCalculator
  HALF_LIFE_DAYS = 90.0
  DECAY_RATE = Math.log(2) / HALF_LIFE_DAYS

  # Devuelve { "Ruby" => 42.3, "SQL/Base de datos" => 11.0, ... }
  # ordenado de mayor a menor score.
  def self.map_for(contributor, as_of: Time.current)
    changes = FileChange
              .joins(:pull_request)
              .where(contributor: contributor)
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

  # Score de un contributor para un conjunto concreto de techs (los tocados
  # por una PR nueva) — lo usa ReviewerSelector para puntuar candidatos.
  def self.score_for_techs(contributor, techs, as_of: Time.current)
    full_map = map_for(contributor, as_of: as_of)
    techs.sum { |tech| full_map.fetch(tech, 0.0) }
  end
end
