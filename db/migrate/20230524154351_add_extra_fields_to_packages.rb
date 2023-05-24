class AddExtraFieldsToPackages < ActiveRecord::Migration[7.0]
  def change
    add_column :packages, :downloads, :integer
    add_column :packages, :dependent_repos_count, :integer
    add_column :packages, :avg_time_to_close_issue, :integer
    add_column :packages, :issues_closed_count, :integer
    add_column :packages, :issues_count, :integer
  end
end
