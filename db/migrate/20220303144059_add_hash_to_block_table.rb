class AddHashToBlockTable < ActiveRecord::Migration[7.0]
  def change
    add_column :blocks, :block_hash, :blob
  end
end
