# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReviewAssignment do
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
end
