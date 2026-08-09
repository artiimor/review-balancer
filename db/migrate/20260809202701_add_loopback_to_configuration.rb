# frozen_string_literal: true

class AddlookbackToConfiguration < ActiveRecord::Migration[7.2]
  def change
    add_column :configurations, :lookback_months, :integer, default: 12
  end
end
