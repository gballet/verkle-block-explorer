class VerifierGoField < ActiveRecord::Migration[7.0]
  def change
    add_column :blocks, :go_verified, :boolean, default: nil, null: true
  end
end
