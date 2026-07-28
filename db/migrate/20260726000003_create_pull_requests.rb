# frozen_string_literal: true

class CreatePullRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :pull_requests do |t|
      t.references :repository, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :contributors }
      t.integer :github_number, null: false
      t.string :title
      t.string :state, null: false, default: 'open' # open | merged | closed
      t.datetime :opened_at, null: false
      t.datetime :merged_at
      t.timestamps
    end

    add_index :pull_requests, %i[repository_id github_number], unique: true
  end
end
