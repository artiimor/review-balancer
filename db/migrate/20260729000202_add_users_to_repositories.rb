# frozen_string_literal: true

class AddUsersToRepositories < ActiveRecord::Migration[7.1]
  def change
    add_reference :repositories, :user, index: true
  end
end
