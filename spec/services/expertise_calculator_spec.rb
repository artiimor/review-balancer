# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExpertiseCalculator do
  let(:user) { User.create!(email: 'user@example.com', password: 'password123') }
  let(:repository) { Repository.create!(github_full_name: 'arturo/demo', webhook_secret: 's3cr3t', user: user) }
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

  it 'raises the score of a technology when there are recent changes in it' do
    pr = merged_pr(days_ago: 1)
    FileChange.create!(pull_request: pr, contributor: contributor, path: 'app/models/user.rb',
                       tech: 'Ruby', lines_changed: 100)

    scores = described_class.map_for(contributor, repository)

    expect(scores['Ruby']).to be > 0
  end

  it 'weighs a change from 6 months ago much less than one from yesterday' do
    old_pr = merged_pr(days_ago: 180)
    recent_pr = merged_pr(days_ago: 1)

    FileChange.create!(pull_request: old_pr, contributor: contributor, path: 'a.rb',
                       tech: 'Ruby', lines_changed: 100)
    FileChange.create!(pull_request: recent_pr, contributor: contributor, path: 'b.rb',
                       tech: 'Ruby', lines_changed: 100)

    scores = described_class.map_for(contributor, repository)

    # With a 90-day half-life, 180 days of age decays to 1/4 of the original weight.
    # The total should be much closer to "100 + 100*0.25" than to "100 + 100".
    expect(scores['Ruby']).to be < 175
    expect(scores['Ruby']).to be > 100
  end

  it 'score_for_techs only sums the requested technologies, ignoring the rest' do
    pr = merged_pr(days_ago: 1)
    FileChange.create!(pull_request: pr, contributor: contributor, path: 'a.rb',
                       tech: 'Ruby', lines_changed: 50)
    FileChange.create!(pull_request: pr, contributor: contributor, path: 'a.js',
                       tech: 'JavaScript/Frontend', lines_changed: 999)

    score = described_class.score_for_techs(contributor, ['Ruby'], repository)

    expect(score).to be_within(1).of(50)
  end

  it 'map_for returns the hash sorted from highest to lowest score' do
    pr = merged_pr(days_ago: 1)
    FileChange.create!(pull_request: pr, contributor: contributor, path: 'a.rb',
                       tech: 'Ruby', lines_changed: 10)
    FileChange.create!(pull_request: pr, contributor: contributor, path: 'a.js',
                       tech: 'JavaScript/Frontend', lines_changed: 100)
    FileChange.create!(pull_request: pr, contributor: contributor, path: 'a.sql',
                       tech: 'SQL/Base de datos', lines_changed: 50)

    scores = described_class.map_for(contributor, repository)

    expect(scores.values).to eq(scores.values.sort.reverse)
    expect(scores.keys.first).to eq('JavaScript/Frontend')
  end

  it 'ignores PRs that have not been merged' do
    open_pr = PullRequest.create!(
      repository: repository, author: other_author, github_number: 1,
      opened_at: 1.day.ago, state: 'open'
    )
    FileChange.create!(pull_request: open_pr, contributor: contributor, path: 'a.rb',
                       tech: 'Ruby', lines_changed: 500)

    scores = described_class.map_for(contributor, repository)

    expect(scores['Ruby']).to be_nil.or eq(0.0)
  end

  context 'when the contributor is in two different repositories' do
    let(:other_repository) do
      Repository.create!(github_full_name: 'arturo/other', webhook_secret: 's3cr3t', user: user)
    end
    def other_merged_pr(days_ago:, author: other_author)
      PullRequest.create!(
        repository: other_repository,
        author: author,
        github_number: rand(1..100_000),
        opened_at: (days_ago + 1).days.ago,
        merged_at: days_ago.days.ago,
        state: 'merged'
      )
    end

    it 'only counts the changes in the given repository' do
      pr = merged_pr(days_ago: 1)
      other_pr = other_merged_pr(days_ago: 1)

      FileChange.create!(pull_request: pr, contributor: contributor, path: 'app/models/user.rb',
                         tech: 'Ruby', lines_changed: 100)
      FileChange.create!(pull_request: other_pr, contributor: contributor, path: 'hello_world.c',
                         tech: 'C', lines_changed: 100)

      scores = described_class.map_for(contributor, repository)

      expect(scores['Ruby']).to be > 0
      expect(scores['C']).to be_nil.or eq(0.0)

      other_scores = described_class.map_for(contributor, other_repository)
      expect(other_scores['C']).to be > 0
      expect(other_scores['Ruby']).to be_nil.or eq(0.0)
    end
  end
end
