# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Repository do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:pull_requests).dependent(:destroy) }
    it { is_expected.to have_many(:repository_contributors).dependent(:destroy) }
    it { is_expected.to have_many(:contributors).through(:repository_contributors) }
  end

  describe 'validations' do
    subject { build(:repository) }

    it { is_expected.to validate_presence_of(:github_full_name) }
    it { is_expected.to validate_uniqueness_of(:github_full_name) }
    it { is_expected.to validate_presence_of(:webhook_secret) }
    it { is_expected.to validate_presence_of(:provider) }
    it { is_expected.to validate_inclusion_of(:provider).in_array(%w[github gitlab]) }
  end

  describe 'webhook_secret encryption' do
    it 'stores webhook_secret encrypted at rest' do
      repository = create(:repository, webhook_secret: 'super-secreto')

      raw_value = ActiveRecord::Base.connection.select_value(
        ActiveRecord::Base.sanitize_sql(['SELECT webhook_secret FROM repositories WHERE id = ?', repository.id])
      )

      expect(raw_value).not_to eq('super-secreto')
      expect(repository.reload.webhook_secret).to eq('super-secreto')
    end
  end
end
