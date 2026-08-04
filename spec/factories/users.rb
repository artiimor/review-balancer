# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }

    after(:build) do |user|
      user.configuration = build(:configuration, user: user)
    end
  end
end
