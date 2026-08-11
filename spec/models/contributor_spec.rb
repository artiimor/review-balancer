# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contributor do
  describe 'associations' do
    it {
      is_expected.to have_many(:authored_pull_requests)
        .class_name('PullRequest')
        .with_foreign_key('author_id')
        .dependent(:restrict_with_error)
    }
    it { is_expected.to have_many(:review_assignments).with_foreign_key('reviewer_id').dependent(:destroy) }
    it { is_expected.to have_many(:file_changes).dependent(:destroy) }
    it { is_expected.to have_many(:repository_contributors).dependent(:destroy) }
    it { is_expected.to have_many(:repositories).through(:repository_contributors) }
    it { is_expected.to have_many(:holidays) }

    it 'prevents destroying a contributor that authored a pull_request' do
      contributor = create(:contributor)
      create(:pull_request, author: contributor)

      expect(contributor.destroy).to be(false)
      expect(contributor.errors[:base]).to be_present
      expect(Contributor.exists?(contributor.id)).to be(true)
    end
  end

  describe 'validations' do
    subject { build(:contributor) }

    it { is_expected.to validate_presence_of(:github_login) }
    it { is_expected.to validate_uniqueness_of(:github_login) }
  end

  describe 'scopes' do
    describe '.not_in_holidays' do
      it 'excludes a contributor currently on holiday' do
        on_holiday = create(:contributor)
        free = create(:contributor)
        create(:holiday, contributor: on_holiday, start_date: 1.day.ago, end_date: 1.day.from_now)

        expect(Contributor.not_in_holidays).to contain_exactly(free)
      end

      it 'includes a contributor whose holiday has already ended' do
        contributor = create(:contributor)
        create(:holiday, contributor: contributor, start_date: 10.days.ago, end_date: 5.days.ago)

        expect(Contributor.not_in_holidays).to include(contributor)
      end

      it 'includes a contributor whose holiday has not started yet' do
        contributor = create(:contributor)
        create(:holiday, contributor: contributor, start_date: 5.days.from_now, end_date: 10.days.from_now)

        expect(Contributor.not_in_holidays).to include(contributor)
      end

      it 'excludes a contributor with several holidays when at least one of them is current' do
        contributor = create(:contributor)
        create(:holiday, contributor: contributor, start_date: 10.days.ago, end_date: 5.days.ago)
        create(:holiday, contributor: contributor, start_date: 1.day.ago, end_date: 1.day.from_now)

        expect(Contributor.not_in_holidays).not_to include(contributor)
      end
    end
  end

  describe '#current_review_load' do
    it 'is zero when there are no review_assignments' do
      contributor = create(:contributor)

      expect(contributor.current_review_load).to eq(0)
    end

    it 'counts only review_assignments without completed_at' do
      contributor = create(:contributor)
      create(:review_assignment, reviewer: contributor, completed_at: nil)
      create(:review_assignment, reviewer: contributor, completed_at: nil)
      create(:review_assignment, reviewer: contributor, completed_at: Time.current)

      expect(contributor.current_review_load).to eq(2)
    end
  end
end
