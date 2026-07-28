# frozen_string_literal: true

class CreateReviewAssignments < ActiveRecord::Migration[7.1]
  def change
    create_table :review_assignments do |t|
      t.references :pull_request, null: false, foreign_key: true
      t.references :reviewer, null: false, foreign_key: { to_table: :contributors }
      t.datetime :assigned_at, null: false
      t.datetime :completed_at
      t.timestamps
    end
  end
end
