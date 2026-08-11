# frozen_string_literal: true

class RepositoryContributor < ApplicationRecord
  belongs_to :repository
  belongs_to :contributor

  validates :contributor_id, uniqueness: { scope: :repository_id }

  scope :active, -> { where(active: true) }
end
