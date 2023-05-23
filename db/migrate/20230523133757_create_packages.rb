class CreatePackages < ActiveRecord::Migration[7.0]
  def change
    create_table :packages do |t|
      t.integer :registry_id
      t.string :name
      t.json :metadata
      t.json :issue_data
      t.datetime :last_synced_at
      t.float :usage_rank
      t.float :quality_rank
      t.float :production

      t.timestamps
    end
  end
end
