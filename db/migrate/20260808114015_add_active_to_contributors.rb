class AddActiveToContributors < ActiveRecord::Migration[7.2]
  def change
    add_column :contributors, :active, :boolean, default: true
  end
end
