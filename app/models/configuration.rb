# frozen_string_literal: true

class Configuration < ApplicationRecord
  DEFAULT_GITLAB_URL = 'https://gitlab.com'

  validates :lookback_months, presence: true, numericality: { in: 1..48 }
  validate :gitlab_url_must_be_safe

  belongs_to :user

  encrypts :github_access_token
  encrypts :gitlab_access_token

  def gitlab_api_endpoint
    url = gitlab_url.presence || DEFAULT_GITLAB_URL
    SsrfProtection.assert_safe!(url)
    "#{url}/api/v4"
  end

  private

  def gitlab_url_must_be_safe
    return if gitlab_url.blank?

    errors.add(:gitlab_url, I18n.t('models.configuration.unsafe_gitlab_url')) unless SsrfProtection.safe?(gitlab_url)
  end
end
