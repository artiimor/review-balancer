# frozen_string_literal: true

class Configuration < ApplicationRecord
  DEFAULT_GITLAB_URL = 'https://gitlab.com'

  validates :lookback_months, presence: true, numericality: { in: 1..48 }

  belongs_to :user

  encrypts :github_access_token
  encrypts :gitlab_access_token

  def gitlab_api_endpoint
    "#{gitlab_url.presence || DEFAULT_GITLAB_URL}/api/v4"
  end
end
