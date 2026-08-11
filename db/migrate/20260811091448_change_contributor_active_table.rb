# frozen_string_literal: true

class ChangeContributorActiveTable < ActiveRecord::Migration[7.2]
  def change
    add_column :repository_contributors, :active, :boolean, default: true
    remove_column :contributors, :active, :boolean, default: true
  end
end
