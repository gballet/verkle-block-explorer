# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2022_07_11_130414) do
  create_table "blocks", force: :cascade do |t|
    t.integer "number"
    t.binary "rlp"
    t.binary "block_hash"
    t.boolean "rust_verified"
    t.boolean "tree_verified"
    t.boolean "go_verified"
  end

  create_table "txes", force: :cascade do |t|
    t.integer "block_id"
    t.binary "tx_hash"
    t.index ["block_id"], name: "index_txes_on_block_id"
  end

  add_foreign_key "txes", "blocks"
end
