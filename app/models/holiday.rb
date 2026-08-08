# frozen_string_literal: true

class Holiday < ApplicationRecord
  validates :start_date, presence: true
  validates :end_date, presence: true

  belongs_to :contributor
end
