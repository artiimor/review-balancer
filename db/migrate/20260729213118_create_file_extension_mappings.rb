# frozen_string_literal: true

class CreateFileExtensionMappings < ActiveRecord::Migration[7.1]
  def change
    create_table :file_extension_mappings do |t|
      t.string :extension, null: false
      t.string :tech, null: false

      t.timestamps
    end

    add_index :file_extension_mappings, :extension, unique: true
  end
end
