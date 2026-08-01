# frozen_string_literal: true

FactoryBot.define do
  factory :pull_request do
    association :repository
    association :author, factory: :contributor
    sequence(:github_number) { |n| n }
    title { 'Sample PR' }
    opened_at { Time.current }
  end
end
