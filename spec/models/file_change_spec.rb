# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FileChange do
  describe 'associations' do
    it { is_expected.to belong_to(:pull_request) }
    it { is_expected.to belong_to(:contributor) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:path) }
    it { is_expected.to validate_presence_of(:tech) }
    it { is_expected.to validate_numericality_of(:lines_changed).is_greater_than_or_equal_to(0) }
  end
end
