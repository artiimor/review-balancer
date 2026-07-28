# frozen_string_literal: true

class CreateContributors < ActiveRecord::Migration[7.1]
  def change
    create_table :contributors do |t|
      t.string :github_login, null: false
      t.string :name
      t.timestamps
    end

    add_index :contributors, :github_login, unique: true
  end
end
