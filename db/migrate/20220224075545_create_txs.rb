class CreateTxs < ActiveRecord::Migration[7.0]
  def change
    create_table :txs do |t|
      t.belongs_to :block, foreign_key: true
      t.blob :tx_hash
    end
  end
end
