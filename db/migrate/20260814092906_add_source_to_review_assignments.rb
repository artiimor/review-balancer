# frozen_string_literal: true

class AddSourceToReviewAssignments < ActiveRecord::Migration[7.2]
  def change
    add_column :review_assignments, :source, :string, null: false, default: 'auto'
  end
end
