# frozen_string_literal: true

class FileChange < ApplicationRecord
  belongs_to :pull_request
  belongs_to :contributor

  validates :path, presence: true
  validates :tech, presence: true
  validates :lines_changed, numericality: { greater_than_or_equal_to: 0 }
end
