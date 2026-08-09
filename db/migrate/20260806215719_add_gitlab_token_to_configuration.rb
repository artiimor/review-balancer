# frozen_string_literal: true

class AddGitlabTokenToConfiguration < ActiveRecord::Migration[7.2]
  def change
    add_column :configurations, :gitlab_access_token, :string
  end
end
