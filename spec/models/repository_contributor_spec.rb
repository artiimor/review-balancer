# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepositoryContributor do
  describe 'associations' do
    it { is_expected.to belong_to(:repository) }
    it { is_expected.to belong_to(:contributor) }
  end

  describe 'validations' do
    subject { build(:repository_contributor) }

    it { is_expected.to validate_uniqueness_of(:contributor_id).scoped_to(:repository_id) }
  end
end
