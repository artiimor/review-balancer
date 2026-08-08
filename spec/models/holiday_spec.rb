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
end
