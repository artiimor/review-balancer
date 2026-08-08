# frozen_string_literal: true

FactoryBot.define do
  factory :holiday do
    association :contributor
    start_date { 1.day.from_now }
    end_date { 5.days.from_now }
  end
end
