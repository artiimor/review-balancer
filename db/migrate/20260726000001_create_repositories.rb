# frozen_string_literal: true

class CreateRepositories < ActiveRecord::Migration[7.1]
  def change
    create_table :repositories do |t|
      t.string :github_full_name, null: false
      t.string :webhook_secret, null: false
      t.timestamps
    end

    add_index :repositories, :github_full_name, unique: true
  end
end
