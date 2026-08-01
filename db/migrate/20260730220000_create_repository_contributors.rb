# frozen_string_literal: true

class CreateRepositoryContributors < ActiveRecord::Migration[7.1]
  def change
    create_table :repository_contributors do |t|
      t.references :repository, null: false, foreign_key: true
      t.references :contributor, null: false, foreign_key: true

      t.timestamps
    end

    add_index :repository_contributors, %i[repository_id contributor_id], unique: true
  end
end
