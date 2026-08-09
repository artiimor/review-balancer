# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PullRequest do
  describe '#ensure_author_is_repository_contributor' do
    it 'links the author as a repository contributor after creation' do
      repository = create(:repository)
      author = create(:contributor)

      expect(repository.contributors).not_to include(author)

      create(:pull_request, repository: repository, author: author)

      expect(repository.contributors.reload).to include(author)
    end

    it 'does not duplicate the link if the author is already a repository contributor' do
      repository = create(:repository)
      author = create(:contributor)
      create(:pull_request, repository: repository, author: author)

      expect do
        create(:pull_request, repository: repository, author: author)
      end.not_to change(RepositoryContributor, :count)
    end
  end

  describe '#merged?' do
    it 'is true when state is "merged"' do
      pull_request = create(:pull_request, state: 'merged')
      expect(pull_request.merged?).to be(true)
    end

    it 'is false when state is not "merged"' do
      pull_request = create(:pull_request, state: 'open')
      expect(pull_request.merged?).to be(false)
    end
  end

  describe '#current_review_assignment' do
    it 'returns the most recently assigned review_assignment' do
      pull_request = create(:pull_request)
      older = create(:review_assignment, pull_request: pull_request, assigned_at: 2.days.ago)
      newer = create(:review_assignment, pull_request: pull_request, assigned_at: 1.day.ago)

      expect(pull_request.current_review_assignment).to eq(newer)
      expect(pull_request.current_review_assignment).not_to eq(older)
    end

    it 'returns nil when there are no review_assignments' do
      pull_request = create(:pull_request)
      expect(pull_request.current_review_assignment).to be_nil
    end
  end

  describe '.search_by_query' do
    it 'matches by (partial, case-insensitive) title' do
      matching = create(:pull_request, title: 'Fix login bug')
      create(:pull_request, title: 'Add dashboard')

      expect(described_class.search_by_query('LOGIN')).to contain_exactly(matching)
    end

    it 'matches by exact PR number, with or without a leading #' do
      matching = create(:pull_request, github_number: 42)
      create(:pull_request, github_number: 43)

      expect(described_class.search_by_query('42')).to contain_exactly(matching)
      expect(described_class.search_by_query('#42')).to contain_exactly(matching)
    end

    it 'returns everything when the query is blank' do
      create_list(:pull_request, 2)

      expect(described_class.search_by_query(nil).count).to eq(2)
    end

    it 'returns every pull request that matches when more than one does' do
      login_bug = create(:pull_request, title: 'Fix login bug')
      signup_bug = create(:pull_request, title: 'Fix signup bug')
      create(:pull_request, title: 'Add dashboard')

      expect(described_class.search_by_query('bug')).to contain_exactly(login_bug, signup_bug)
    end
  end

  describe '.with_state' do
    it 'filters by state' do
      merged = create(:pull_request, state: 'merged')
      create(:pull_request, state: 'open')

      expect(described_class.with_state('merged')).to contain_exactly(merged)
    end

    it 'returns everything when the state is blank' do
      create_list(:pull_request, 2)

      expect(described_class.with_state(nil).count).to eq(2)
    end

    it 'returns every pull request with the given state when more than one matches' do
      first_open = create(:pull_request, state: 'open')
      second_open = create(:pull_request, state: 'open')
      create(:pull_request, state: 'merged')

      expect(described_class.with_state('open')).to contain_exactly(first_open, second_open)
    end

    it 'matches any of several states when given an array' do
      open_pr = create(:pull_request, state: 'open')
      merged_pr = create(:pull_request, state: 'merged')
      closed_pr = create(:pull_request, state: 'closed')

      expect(described_class.with_state(%w[open merged])).to contain_exactly(open_pr, merged_pr)
      expect(described_class.with_state(%w[open merged])).not_to include(closed_pr)
    end

    it 'ignores blank entries in the array' do
      matching = create(:pull_request, state: 'open')
      create(:pull_request, state: 'merged')

      expect(described_class.with_state(['open', '', nil])).to contain_exactly(matching)
    end
  end

  describe '.with_reviewer' do
    it 'filters pull requests assigned to the given reviewer' do
      reviewer = create(:contributor)
      matching = create(:pull_request)
      create(:review_assignment, pull_request: matching, reviewer: reviewer)
      create(:pull_request)

      expect(described_class.with_reviewer(reviewer.id)).to contain_exactly(matching)
    end

    it 'returns everything when the reviewer_id is blank' do
      create_list(:pull_request, 2)

      expect(described_class.with_reviewer(nil).count).to eq(2)
    end

    it 'returns every pull request assigned to the reviewer when more than one matches' do
      reviewer = create(:contributor)
      first_match = create(:pull_request)
      create(:review_assignment, pull_request: first_match, reviewer: reviewer)
      second_match = create(:pull_request)
      create(:review_assignment, pull_request: second_match, reviewer: reviewer)
      other = create(:pull_request)
      create(:review_assignment, pull_request: other, reviewer: create(:contributor))

      expect(described_class.with_reviewer(reviewer.id)).to contain_exactly(first_match, second_match)
    end

    it 'matches any of several reviewers when given an array' do
      alice = create(:contributor)
      bob = create(:contributor)
      carol = create(:contributor)

      alice_pr = create(:pull_request)
      create(:review_assignment, pull_request: alice_pr, reviewer: alice)
      bob_pr = create(:pull_request)
      create(:review_assignment, pull_request: bob_pr, reviewer: bob)
      carol_pr = create(:pull_request)
      create(:review_assignment, pull_request: carol_pr, reviewer: carol)

      expect(described_class.with_reviewer([alice.id, bob.id])).to contain_exactly(alice_pr, bob_pr)
      expect(described_class.with_reviewer([alice.id, bob.id])).not_to include(carol_pr)
    end
  end

  describe '.with_review_time' do
    it 'buckets completed reviews by their duration' do
      fast = create(:pull_request)
      create(:review_assignment, pull_request: fast, assigned_at: 2.hours.ago, completed_at: 1.hour.ago)

      slow = create(:pull_request)
      create(:review_assignment, pull_request: slow, assigned_at: 5.days.ago, completed_at: 1.day.ago)

      expect(described_class.with_review_time('under_1_day')).to contain_exactly(fast)
      expect(described_class.with_review_time('over_3_days')).to contain_exactly(slow)
    end

    it 'returns every pull request in the bucket when more than one matches' do
      first_fast = create(:pull_request)
      create(:review_assignment, pull_request: first_fast, assigned_at: 2.hours.ago, completed_at: 1.hour.ago)

      second_fast = create(:pull_request)
      create(:review_assignment, pull_request: second_fast, assigned_at: 3.hours.ago, completed_at: 1.hour.ago)

      slow = create(:pull_request)
      create(:review_assignment, pull_request: slow, assigned_at: 5.days.ago, completed_at: 1.day.ago)

      expect(described_class.with_review_time('under_1_day')).to contain_exactly(first_fast, second_fast)
    end

    it 'treats in-progress reviews as ongoing until now' do
      ongoing = create(:pull_request)
      create(:review_assignment, pull_request: ongoing, assigned_at: 5.days.ago, completed_at: nil)

      expect(described_class.with_review_time('over_3_days')).to contain_exactly(ongoing)
    end

    it 'returns everything when the bucket is blank or unknown' do
      create_list(:pull_request, 2)

      expect(described_class.with_review_time(nil).count).to eq(2)
      expect(described_class.with_review_time('bogus').count).to eq(2)
    end
  end
end
