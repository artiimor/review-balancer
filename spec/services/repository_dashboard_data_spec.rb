# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepositoryDashboardData do
  let(:user) { create(:user) }
  let(:repository) { create(:repository, user: user) }

  def merged_pr(author:, days_ago: 1, repo: repository, merged_at: days_ago.days.ago)
    create(:pull_request, repository: repo, author: author,
                          opened_at: merged_at - 1.hour, merged_at: merged_at, state: 'merged')
  end

  describe '.call' do
    it 'returns a hash with pending_reviews, techs and expertise_rows' do
      result = described_class.call(repository)

      expect(result.keys).to contain_exactly(:pending_reviews, :techs, :expertise_rows)
    end
  end

  describe 'pending_reviews' do
    it 'includes one entry per repository contributor with their current review load, ordered by github_login' do
      bob = create(:contributor, github_login: 'bob')
      alice = create(:contributor, github_login: 'alice')
      pr_bob = merged_pr(author: bob)
      pr_alice = merged_pr(author: alice)
      create(:review_assignment, pull_request: pr_bob, reviewer: bob, completed_at: nil)
      create(:review_assignment, pull_request: pr_alice, reviewer: alice, completed_at: nil)
      create(:review_assignment, pull_request: pr_alice, reviewer: alice, completed_at: nil)

      result = described_class.call(repository)

      expect(result[:pending_reviews].map(&:contributor)).to eq([alice, bob])
      expect(result[:pending_reviews].map(&:pending_reviews)).to eq([2, 1])
    end

    it 'is empty when the repository has no contributors' do
      result = described_class.call(repository)

      expect(result[:pending_reviews]).to eq([])
    end
  end

  describe 'techs' do
    it 'lists the distinct techs touched in the repository, sorted alphabetically' do
      contributor = create(:contributor)
      pr = merged_pr(author: contributor)
      create(:file_change, pull_request: pr, contributor: contributor, tech: 'Ruby')
      create(:file_change, pull_request: pr, contributor: contributor, tech: 'JavaScript/Frontend')

      result = described_class.call(repository)

      expect(result[:techs]).to eq(%w[JavaScript/Frontend Ruby])
    end

    it 'does not include techs from other repositories' do
      other_repository = create(:repository)
      contributor = create(:contributor)
      pr = merged_pr(author: contributor, repo: other_repository)
      create(:file_change, pull_request: pr, contributor: contributor, tech: 'Ruby')

      result = described_class.call(repository)

      expect(result[:techs]).to eq([])
    end

    it 'includes techs even from pull_requests that are not merged (unlike ExpertiseCalculator)' do
      contributor = create(:contributor)
      open_pr = create(:pull_request, repository: repository, author: contributor, opened_at: 1.hour.ago, state: 'open')
      create(:file_change, pull_request: open_pr, contributor: contributor, tech: 'Ruby')

      result = described_class.call(repository)

      expect(result[:techs]).to eq(['Ruby'])
    end
  end

  describe 'expertise_rows' do
    it 'is empty when the repository has no contributors' do
      result = described_class.call(repository)

      expect(result[:expertise_rows]).to eq([])
    end

    it 'is empty when the repository has contributors but no recorded techs' do
      create(:repository_contributor, repository: repository)

      result = described_class.call(repository)

      expect(result[:expertise_rows]).to eq([])
    end

    it 'builds one row per contributor with one cell per tech' do
      alice = create(:contributor, github_login: 'alice')
      bob = create(:contributor, github_login: 'bob')
      pr = merged_pr(author: alice)
      create(:file_change, pull_request: pr, contributor: alice, tech: 'Ruby', lines_changed: 100)
      create(:repository_contributor, repository: repository, contributor: bob)

      result = described_class.call(repository)

      expect(result[:expertise_rows].map { |row| row[:contributor] }).to contain_exactly(alice, bob)
      row = result[:expertise_rows].find { |r| r[:contributor] == alice }
      expect(row[:cells].map(&:tech)).to eq(['Ruby'])
    end

    it 'labels the contributors with the least, middling, and most expertise as bajo/medio/alto' do
      low = create(:contributor, github_login: 'low')
      mid = create(:contributor, github_login: 'mid')
      high = create(:contributor, github_login: 'high')

      create(:file_change, pull_request: merged_pr(author: low), contributor: low, tech: 'Ruby', lines_changed: 10)
      create(:file_change, pull_request: merged_pr(author: mid), contributor: mid, tech: 'Ruby', lines_changed: 50)
      create(:file_change, pull_request: merged_pr(author: high), contributor: high, tech: 'Ruby', lines_changed: 200)

      result = described_class.call(repository)

      levels = result[:expertise_rows].to_h do |row|
        [row[:contributor], row[:cells].first.level]
      end

      expect(levels[low]).to eq('bajo')
      expect(levels[mid]).to eq('medio')
      expect(levels[high]).to eq('alto')
    end

    it 'labels everyone as alto when they all share the same nonzero score (thresholds collapse to 0)' do
      moment = 1.day.ago
      alice = create(:contributor, github_login: 'alice')
      bob = create(:contributor, github_login: 'bob')

      create(:file_change, pull_request: merged_pr(author: alice, merged_at: moment), contributor: alice,
                           tech: 'Ruby', lines_changed: 100)
      create(:file_change, pull_request: merged_pr(author: bob, merged_at: moment), contributor: bob,
                           tech: 'Ruby', lines_changed: 100)

      result = nil
      freeze_time { result = described_class.call(repository) }

      levels = result[:expertise_rows].map { |row| row[:cells].first.level }
      expect(levels).to all(eq('alto'))
    end

    it 'does not label a contributor with a stale, heavily decayed score as alto just because most tech cells are 0' do
      alice = create(:contributor, github_login: 'alice')
      bob = create(:contributor, github_login: 'bob')
      carol = create(:contributor, github_login: 'carol')

      create(:file_change, pull_request: merged_pr(author: alice, days_ago: 1), contributor: alice,
                           tech: 'Ruby', lines_changed: 200)
      create(:file_change, pull_request: merged_pr(author: bob, days_ago: 1), contributor: bob,
                           tech: 'JavaScript', lines_changed: 200)
      create(:file_change, pull_request: merged_pr(author: carol, days_ago: 900), contributor: carol,
                           tech: 'Python', lines_changed: 50)

      result = described_class.call(repository)

      row = result[:expertise_rows].find { |r| r[:contributor] == carol }
      python_cell = row[:cells].find { |c| c.tech == 'Python' }
      expect(python_cell.level).to eq('bajo')
    end

    it 'labels a contributor with no expertise in a tech as bajo (score 0)' do
      contributor_with_ruby = create(:contributor, github_login: 'ruby-dev')
      contributor_without = create(:contributor, github_login: 'no-signal')
      pr = merged_pr(author: contributor_with_ruby)
      create(:file_change, pull_request: pr, contributor: contributor_with_ruby, tech: 'Ruby', lines_changed: 100)
      create(:repository_contributor, repository: repository, contributor: contributor_without)

      result = described_class.call(repository)

      row = result[:expertise_rows].find { |r| r[:contributor] == contributor_without }
      expect(row[:cells].first.score).to eq(0.0)
      expect(row[:cells].first.level).to eq('cero')
    end
  end
end
