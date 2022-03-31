class VerifierFields < ActiveRecord::Migration[7.0]
  def change
    add_column :blocks, :rust_verified, :boolean, default: nil, null: true
    add_column :blocks, :tree_verified, :boolean, default: nil, null: true
  end
end
