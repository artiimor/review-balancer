# frozen_string_literal: true

class AddGitlabUrlToConfigurations < ActiveRecord::Migration[7.2]
  def change
    add_column :configurations, :gitlab_url, :string
  end
end
