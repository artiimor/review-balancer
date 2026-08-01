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
end
