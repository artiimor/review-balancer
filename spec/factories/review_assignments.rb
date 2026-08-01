# frozen_string_literal: true

FactoryBot.define do
  factory :review_assignment do
    association :pull_request
    association :reviewer, factory: :contributor
    assigned_at { Time.current }
  end
end
