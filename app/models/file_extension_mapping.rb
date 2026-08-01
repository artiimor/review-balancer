# frozen_string_literal: true

class FileExtensionMapping < ApplicationRecord
  validates :extension, presence: true, uniqueness: true
  validates :tech, presence: true
end
