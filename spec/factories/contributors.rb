# frozen_string_literal: true

FactoryBot.define do
  factory :contributor do
    sequence(:github_login) { |n| "contributor-#{n}" }
  end
end
