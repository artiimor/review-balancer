# frozen_string_literal: true

class Holiday < ApplicationRecord
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :start_date_is_before_end_date

  belongs_to :contributor

  scope :current, -> { where('start_date <= ? AND end_date >= ?', Time.current, Time.current) }

  private

  def start_date_is_before_end_date
    return if start_date.blank? || end_date.blank?

    errors.add(:start_date, I18n.t('models.holiday.date_error')) if start_date >= end_date
  end
end
