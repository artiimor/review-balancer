# frozen_string_literal: true

class AddProviderToRepositories < ActiveRecord::Migration[7.2]
  def change
    add_column :repositories, :provider, :string, null: false, default: 'github'
  end
end
