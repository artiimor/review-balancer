# frozen_string_literal: true

class Repository < ApplicationRecord
  encrypts :webhook_secret

  has_many :pull_requests, dependent: :destroy

  validates :github_full_name, presence: true, uniqueness: true
  validates :webhook_secret, presence: true
end
