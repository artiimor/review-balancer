# frozen_string_literal: true

class User < ApplicationRecord
  has_many :repositories

  has_one :configuration, dependent: :destroy

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
end
