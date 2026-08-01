# frozen_string_literal: true

FactoryBot.define do
  factory :repository_contributor do
    association :repository
    association :contributor
  end
end
