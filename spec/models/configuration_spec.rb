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

    it 'raises when the configured gitlab_url points to a non-public address' do
      configuration = build(:configuration, gitlab_url: 'https://127.0.0.1')

      expect { configuration.gitlab_api_endpoint }.to raise_error(SsrfProtection::UnsafeUrlError)
    end
  end

  describe '#gitlab_client' do
    it 'pins the connection to the resolved IP of the configured host' do
      configuration = build(:configuration, gitlab_url: 'https://gitlab.example.com')
      allow(SsrfProtection).to receive(:resolve_pinned_ip!)
        .with('https://gitlab.example.com').and_return('93.184.216.34')
      gitlab_client = instance_double(Gitlab::Client)
      expect(Gitlab).to receive(:client)
        .with(
          endpoint: 'https://gitlab.example.com/api/v4', private_token: 'secret-token',
          httparty: {
            connection_adapter: Gitlab::PinnedConnectionAdapter,
            connection_adapter_options: { ssrf_safe_ip: '93.184.216.34' }
          }
        )
        .and_return(gitlab_client)

      expect(configuration.gitlab_client(private_token: 'secret-token')).to eq(gitlab_client)
    end

    it 'raises instead of building a client when the configured gitlab_url is unsafe' do
      configuration = build(:configuration, gitlab_url: 'https://127.0.0.1')

      expect { configuration.gitlab_client(private_token: 'secret-token') }
        .to raise_error(SsrfProtection::UnsafeUrlError)
    end
  end

  describe 'gitlab_url safety (SSRF protection)' do
    it 'is valid without a gitlab_url' do
      configuration = build(:configuration, user: create(:user), gitlab_url: nil)

      expect(configuration).to be_valid
    end

    it 'is valid with a public https gitlab_url' do
      configuration = build(:configuration, user: create(:user), gitlab_url: 'https://8.8.8.8')

      expect(configuration).to be_valid
    end

    it 'is invalid with a non-https gitlab_url' do
      configuration = build(:configuration, user: create(:user), gitlab_url: 'http://gitlab.example.com')

      expect(configuration).not_to be_valid
      expect(configuration.errors[:gitlab_url]).to include(I18n.t('models.configuration.unsafe_gitlab_url'))
    end

    it 'is invalid when gitlab_url resolves to a loopback address' do
      configuration = build(:configuration, user: create(:user), gitlab_url: 'https://127.0.0.1')

      expect(configuration).not_to be_valid
      expect(configuration.errors[:gitlab_url]).to include(I18n.t('models.configuration.unsafe_gitlab_url'))
    end

    it 'is invalid when gitlab_url resolves to a private network address' do
      configuration = build(:configuration, user: create(:user), gitlab_url: 'https://10.0.0.5')

      expect(configuration).not_to be_valid
      expect(configuration.errors[:gitlab_url]).to include(I18n.t('models.configuration.unsafe_gitlab_url'))
    end

    it 'is invalid when gitlab_url resolves to the cloud metadata address' do
      configuration = build(:configuration, user: create(:user), gitlab_url: 'https://169.254.169.254')

      expect(configuration).not_to be_valid
      expect(configuration.errors[:gitlab_url]).to include(I18n.t('models.configuration.unsafe_gitlab_url'))
    end
  end
end
