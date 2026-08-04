require 'rails_helper'

RSpec.describe Configuration, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'github_token encryption' do
    let(:user) { create(:user) }

    it 'stores github_access_token encrypted at rest' do
      configuration = create(:configuration, user: user, github_access_token: 'super-secreto')

      raw_value = ActiveRecord::Base.connection.select_value(
        ActiveRecord::Base.sanitize_sql(['SELECT github_access_token FROM configurations WHERE id = ?', configuration.id])
      )

      expect(raw_value).not_to eq('super-secreto')
      expect(configuration.reload.github_access_token).to eq('super-secreto')
    end
  end
end
