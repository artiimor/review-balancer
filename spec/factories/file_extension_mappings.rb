# frozen_string_literal: true

FactoryBot.define do
  factory :file_extension_mapping do
    sequence(:extension) { |n| ".ext#{n}" }
    tech { 'Ruby' }
  end
end
