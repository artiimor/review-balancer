# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReviewerSelector do
  let(:repository) { Repository.create!(github_full_name: 'arturo/demo', webhook_secret: 's3cr3t') }
  let(:author) { Contributor.create!(github_login: 'autora-pr') }
  let(:experta_ruby) { Contributor.create!(github_login: 'experta-ruby') }
  let(:experta_saturada) { Contributor.create!(github_login: 'experta-saturada') }
  let(:novato) { Contributor.create!(github_login: 'novato') }

  def merged_pr_touching(contributor, tech, lines:, days_ago: 1)
    pr = PullRequest.create!(
      repository: repository, author: contributor, github_number: rand(1..999_999),
      opened_at: (days_ago + 1).days.ago, merged_at: days_ago.days.ago, state: 'merged'
    )
    FileChange.create!(pull_request: pr, contributor: contributor, path: 'x.rb', tech: tech, lines_changed: lines)
    pr
  end

  def open_pr_touching(tech)
    PullRequest.create!(
      repository: repository, author: author, github_number: rand(1..999_999),
      opened_at: 1.hour.ago, state: 'open'
    ).tap do |pr|
      FileChange.create!(pull_request: pr, contributor: author, path: 'y.rb', tech: tech, lines_changed: 10)
    end
  end

  before do
    # Todos han contribuido antes al repo (para aparecer como candidatos).
    merged_pr_touching(experta_ruby, 'Ruby', lines: 500)
    merged_pr_touching(experta_saturada, 'Ruby', lines: 800)
    merged_pr_touching(novato, 'Ruby', lines: 5)
  end

  it 'prioriza a quien más sabe de la tecnología tocada, entre los candidatos con carga similar' do
    pr = open_pr_touching('Ruby')

    ranked = described_class.rank(pr, top_n: 3)
    top_choice = ranked.first[:contributor]

    expect(top_choice).to eq(experta_saturada).or eq(experta_ruby)
    expect(ranked.first[:score]).to be > ranked.last[:score]
  end

  it 'penaliza a un experto saturado frente a alguien con menos carga aunque sepa algo menos' do
    pr = open_pr_touching('Ruby')

    # Saturamos a experta_saturada con 5 revisiones pendientes.
    5.times do
      ReviewAssignment.create!(pull_request: pr, reviewer: experta_saturada, assigned_at: Time.current)
    end

    ranked = described_class.rank(pr, top_n: 3)
    top_choice = ranked.first[:contributor]

    expect(top_choice).to eq(experta_ruby)
  end

  it 'nunca elige al autor de la PR como su propio revisor' do
    pr = open_pr_touching('Ruby')

    ranked = described_class.rank(pr, top_n: 10)

    expect(ranked.map { |r| r[:contributor] }).not_to include(author)
  end

  it 'assign! crea el ReviewAssignment con el mejor candidato' do
    pr = open_pr_touching('Ruby')

    assignment = described_class.assign!(pr)

    expect(assignment).to be_persisted
    expect(assignment.pull_request).to eq(pr)
  end
end
