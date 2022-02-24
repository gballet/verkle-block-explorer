class RenameTxs < ActiveRecord::Migration[7.0]
  def self.up
    rename_table :txs, :txes
  end

  def self.down
    rename_table :txes, :txs
  end
end
