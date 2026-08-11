# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Configuration, type: :model do
  describe 'validations' do
    it { should validate_numericality_of(:lookback_months).is_in(1..48) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'github_token encryption' do
    let(:user) { create(:user) }

    it 'stores github_access_token encrypted at rest' do
      configuration = create(:configuration, user: user, github_access_token: 'super-secreto')

      raw_value = ActiveRecord::Base.connection.select_value(
        ActiveRecord::Base.sanitize_sql(['SELECT github_access_token FROM configurations WHERE id = ?',
                                         configuration.id])
      )

      expect(raw_value).not_to eq('super-secreto')
      expect(configuration.reload.github_access_token).to eq('super-secreto')
    end
  end

  describe 'gitlab_token encryption' do
    let(:user) { create(:user) }

    it 'stores gitlab_access_token encrypted at rest' do
      configuration = create(:configuration, user: user, gitlab_access_token: 'super-secreto')

      raw_value = ActiveRecord::Base.connection.select_value(
        ActiveRecord::Base.sanitize_sql(['SELECT gitlab_access_token FROM configurations WHERE id = ?',
                                         configuration.id])
      )

      expect(raw_value).not_to eq('super-secreto')
      expect(configuration.reload.gitlab_access_token).to eq('super-secreto')
    end
  end

  describe '#gitlab_api_endpoint' do
    it 'defaults to gitlab.com when no gitlab_url is set' do
      configuration = build(:configuration, gitlab_url: nil)

      expect(configuration.gitlab_api_endpoint).to eq('https://gitlab.com/api/v4')
    end

    it 'builds the endpoint from the configured gitlab_url' do
      configuration = build(:configuration, gitlab_url: 'https://gitlab.example.com')

      expect(configuration.gitlab_api_endpoint).to eq('https://gitlab.example.com/api/v4')
    end
  end
end
