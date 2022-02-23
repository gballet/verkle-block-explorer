class CreateBlockTable < ActiveRecord::Migration[7.0]
  def change
    create_table :blocks do |t|
      t.integer :number
      t.string :hash
      t.blob :rlp
      t.index ['number'], name: 'number_index'
      t.index ['hash'], name: 'hash_index'
    end
  end
end
