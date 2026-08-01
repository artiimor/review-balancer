# frozen_string_literal: true

class AddMatchedTechToReviewAssignments < ActiveRecord::Migration[7.1]
  def change
    add_column :review_assignments, :matched_tech, :string
  end
end
