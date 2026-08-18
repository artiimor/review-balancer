# frozen_string_literal: true

class Configuration < ApplicationRecord
  DEFAULT_GITLAB_URL = 'https://gitlab.com'

  validates :lookback_months, presence: true, numericality: { in: 1..48 }
  validate :gitlab_url_must_be_safe

  belongs_to :user

  encrypts :github_access_token
  encrypts :gitlab_access_token

  def gitlab_api_endpoint
    SsrfProtection.assert_safe!(gitlab_base_url)
    "#{gitlab_base_url}/api/v4"
  end

  # Avoid DNS-rebinding window a plain
  def gitlab_client(private_token:)
    ssrf_safe_ip = SsrfProtection.resolve_pinned_ip!(gitlab_base_url)

    ::Gitlab.client(
      endpoint: "#{gitlab_base_url}/api/v4",
      private_token: private_token,
      httparty: {
        connection_adapter: Gitlab::PinnedConnectionAdapter,
        connection_adapter_options: { ssrf_safe_ip: ssrf_safe_ip }
      }
    )
  end

  private

  def gitlab_base_url
    gitlab_url.presence || DEFAULT_GITLAB_URL
  end

  def gitlab_url_must_be_safe
    return if gitlab_url.blank?

    errors.add(:gitlab_url, I18n.t('models.configuration.unsafe_gitlab_url')) unless SsrfProtection.safe?(gitlab_url)
  end
end
