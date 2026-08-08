# frozen_string_literal: true

class CreateHolidays < ActiveRecord::Migration[7.2]
  def change
    create_table :holidays do |t|
      t.datetime :start_date, null: false
      t.datetime :end_date, null: false

      t.belongs_to :contributor, index: true
      t.timestamps
    end
  end
end
