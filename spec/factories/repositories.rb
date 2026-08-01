# frozen_string_literal: true

FactoryBot.define do
  factory :repository do
    sequence(:github_full_name) { |n| "octo-org/repo-#{n}" }
    webhook_secret { 'test-secret' }
    association :user
  end
end
