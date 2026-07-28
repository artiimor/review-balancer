# frozen_string_literal: true

class CreateFileChanges < ActiveRecord::Migration[7.1]
  def change
    create_table :file_changes do |t|
      t.references :pull_request, null: false, foreign_key: true
      t.references :contributor, null: false, foreign_key: true
      t.string :path, null: false
      t.string :tech, null: false
      t.integer :lines_changed, null: false, default: 0
      t.timestamps
    end

    add_index :file_changes, %i[contributor_id tech]
  end
end
