# frozen_string_literal: true

FactoryBot.define do
  factory :configuration do
    sequence(:github_access_token) { 'dummy_token' }
  end
end
