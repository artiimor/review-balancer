# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExpertiseCalculator do
  let(:repository) { Repository.create!(github_full_name: 'arturo/demo', webhook_secret: 's3cr3t') }
  let(:contributor) { Contributor.create!(github_login: 'arturo') }
  let(:other_author) { Contributor.create!(github_login: 'otra-persona') }

  def merged_pr(days_ago:, author: other_author)
    PullRequest.create!(
      repository: repository,
      author: author,
      github_number: rand(1..100_000),
      opened_at: (days_ago + 1).days.ago,
      merged_at: days_ago.days.ago,
      state: 'merged'
    )
  end

  it 'sube el score de una tecnología cuando hay cambios recientes en ella' do
    pr = merged_pr(days_ago: 1)
    FileChange.create!(pull_request: pr, contributor: contributor, path: 'app/models/user.rb',
                       tech: 'Ruby', lines_changed: 100)

    scores = described_class.map_for(contributor)

    expect(scores['Ruby']).to be > 0
  end

  it 'hace pesar mucho menos un cambio de hace 6 meses que uno de ayer' do
    old_pr = merged_pr(days_ago: 180)
    recent_pr = merged_pr(days_ago: 1)

    FileChange.create!(pull_request: old_pr, contributor: contributor, path: 'a.rb',
                       tech: 'Ruby', lines_changed: 100)
    FileChange.create!(pull_request: recent_pr, contributor: contributor, path: 'b.rb',
                       tech: 'Ruby', lines_changed: 100)

    scores = described_class.map_for(contributor)

    # Con vida media de 90 días, 180 días de antigüedad decae a 1/4 del peso original.
    # El total debería estar mucho más cerca de "100 + 100*0.25" que de "100 + 100".
    expect(scores['Ruby']).to be < 175
    expect(scores['Ruby']).to be > 100
  end

  it 'score_for_techs solo suma las tecnologías pedidas, ignorando el resto' do
    pr = merged_pr(days_ago: 1)
    FileChange.create!(pull_request: pr, contributor: contributor, path: 'a.rb',
                       tech: 'Ruby', lines_changed: 50)
    FileChange.create!(pull_request: pr, contributor: contributor, path: 'a.js',
                       tech: 'JavaScript/Frontend', lines_changed: 999)

    score = described_class.score_for_techs(contributor, ['Ruby'])

    expect(score).to be_within(1).of(50)
  end

  it 'ignora las PRs que no se han mergeado' do
    open_pr = PullRequest.create!(
      repository: repository, author: other_author, github_number: 1,
      opened_at: 1.day.ago, state: 'open'
    )
    FileChange.create!(pull_request: open_pr, contributor: contributor, path: 'a.rb',
                       tech: 'Ruby', lines_changed: 500)

    scores = described_class.map_for(contributor)

    expect(scores['Ruby']).to be_nil.or eq(0.0)
  end
end
