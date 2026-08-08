# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Holiday, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:contributor) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:start_date) }
    it { is_expected.to validate_presence_of(:end_date) }
  end

  describe 'scopes' do
    describe '.current' do
      it 'includes a holiday that covers today' do
        holiday = create(:holiday, start_date: 1.day.ago, end_date: 1.day.from_now)

        expect(Holiday.current).to include(holiday)
      end

      it 'excludes a holiday that already ended' do
        holiday = create(:holiday, start_date: 10.days.ago, end_date: 5.days.ago)

        expect(Holiday.current).not_to include(holiday)
      end

      it 'excludes a holiday that has not started yet' do
        holiday = create(:holiday, start_date: 5.days.from_now, end_date: 10.days.from_now)

        expect(Holiday.current).not_to include(holiday)
      end
    end
  end
end
