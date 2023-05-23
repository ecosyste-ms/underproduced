class AddSortingFieldsToPackages < ActiveRecord::Migration[7.0]
  def change
    add_column :packages, :usage, :integer
    add_column :packages, :quality, :integer
  end
end
