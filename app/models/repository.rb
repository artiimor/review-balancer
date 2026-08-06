# frozen_string_literal: true

class Repository < ApplicationRecord
  encrypts :webhook_secret

  belongs_to :user

  has_many :pull_requests, dependent: :destroy
  has_many :repository_contributors, dependent: :destroy
  has_many :contributors, through: :repository_contributors

  validates :github_full_name, presence: true, uniqueness: true
  validates :webhook_secret, presence: true

  validates :provider, presence: true, inclusion: { in: %w[github gitlab] }
end
