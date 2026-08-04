# frozen_string_literal: true

class CreateConfigurations < ActiveRecord::Migration[7.2]
  def change
    create_table :configurations do |t|
      t.belongs_to :user, null: false, foreign_key: true
      t.string :github_access_token
      t.timestamps
    end
  end
end
