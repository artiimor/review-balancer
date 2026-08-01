# frozen_string_literal: true

FactoryBot.define do
  factory :file_change do
    association :pull_request
    association :contributor
    sequence(:path) { |n| "app/models/file_#{n}.rb" }
    tech { 'Ruby' }
    lines_changed { 10 }
  end
end
