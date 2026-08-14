# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReviewAssignment do
  describe 'associations' do
    it { is_expected.to belong_to(:pull_request) }
    it { is_expected.to belong_to(:reviewer) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:assigned_at) }
    it { is_expected.to validate_inclusion_of(:source).in_array(%w[auto manual]) }
  end

  describe '#complete!' do
    it 'sets completed_at when it was not completed yet' do
      assignment = create(:review_assignment, completed_at: nil)

      assignment.complete!

      expect(assignment.completed_at).not_to be_nil
    end

    it 'does not overwrite completed_at when it was already completed' do
      completed_at = 2.days.ago
      assignment = create(:review_assignment, completed_at: completed_at)

      assignment.complete!

      expect(assignment.completed_at).to be_within(1.second).of(completed_at)
    end
  end

  describe '#review_duration_end' do
    it 'returns completed_at when the assignment is completed' do
      completed_at = 2.days.ago
      assignment = create(:review_assignment, completed_at: completed_at)

      expect(assignment.review_duration_end).to be_within(1.second).of(completed_at)
    end

    it 'returns the current time when the assignment is not completed yet' do
      assignment = create(:review_assignment, completed_at: nil)
      freeze_time do
        expect(assignment.review_duration_end).to eq(Time.current)
      end
    end
  end

  describe 'broadcasting' do
    it "broadcasts a replace of the pull_request row to the repository's stream on create" do
      repository = create(:repository)
      pull_request = create(:pull_request, repository: repository)

      expect { create(:review_assignment, pull_request: pull_request) }
        .to(have_broadcasted_to(repository.pull_requests_stream_name)
        .with { |html| expect(html).to include('action="replace"', "target=\"pull_request_#{pull_request.id}\"") })
    end

    it 'broadcasts again when the assignment is completed' do
      repository = create(:repository)
      pull_request = create(:pull_request, repository: repository)
      assignment = create(:review_assignment, pull_request: pull_request, completed_at: nil)

      expect { assignment.complete! }
        .to(have_broadcasted_to(repository.pull_requests_stream_name)
        .with { |html| expect(html).to include('action="replace"', "target=\"pull_request_#{pull_request.id}\"") })
    end

    it 'uses fresh data from the database, not a stale cached association, so sibling changes are reflected' do
      repository = create(:repository)
      pull_request = create(:pull_request, repository: repository)
      first_reviewer = create(:contributor, github_login: 'first_reviewer')
      second_reviewer = create(:contributor, github_login: 'second_reviewer')

      previous = create(:review_assignment, pull_request: pull_request, reviewer: first_reviewer, completed_at: nil)
      previous.complete!

      expect { create(:review_assignment, pull_request: pull_request, reviewer: second_reviewer) }
        .to(have_broadcasted_to(repository.pull_requests_stream_name)
        .with { |html| expect(html).to include('second_reviewer') })
    end
  end
end
