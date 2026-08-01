# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contributor do # rubocop:disable Metrics/BlockLength
  describe 'associations' do
    it {
      is_expected.to have_many(:authored_pull_requests)
        .class_name('PullRequest')
        .with_foreign_key('author_id')
        .dependent(:restrict_with_error) }
    it { is_expected.to have_many(:review_assignments).with_foreign_key('reviewer_id').dependent(:destroy) }
    it { is_expected.to have_many(:file_changes).dependent(:destroy) }
    it { is_expected.to have_many(:repository_contributors).dependent(:destroy) }
    it { is_expected.to have_many(:repositories).through(:repository_contributors) }
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
