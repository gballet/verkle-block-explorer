class CreateBlockTable < ActiveRecord::Migration[7.0]
  def change
    create_table :blocks do |t|
      t.integer :number
      t.blob :rlp
    end
  end
end
