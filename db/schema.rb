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

ActiveRecord::Schema[8.1].define(version: 2026_10_06_200000) do
  create_table "categories", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "user_id, lower(name)", name: "index_categories_on_user_id_and_lower_name", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.integer "amount_in_cents", null: false
    t.string "currency", default: "USD", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "name", null: false
    t.date "occurred_on", null: false
    t.integer "category_id"
    t.text "shorthand"
    t.datetime "discarded_at"
    t.string "idempotency_key"
    t.index "user_id, lower(name), occurred_on", name: "index_transactions_on_user_id_and_lower_name_kept", where: "discarded_at IS NULL"
    t.index ["user_id", "idempotency_key"], name: "index_transactions_on_user_id_and_idempotency_key", unique: true, where: "idempotency_key IS NOT NULL"
    t.index ["user_id", "occurred_on", "category_id", "amount_in_cents"], name: "index_transactions_on_user_id_and_occurred_on_kept", where: "discarded_at IS NULL"
    t.index ["user_id", "occurred_on"], name: "index_transactions_on_user_id_and_occurred_on"
  end

  create_table "users", force: :cascade do |t|
    t.string "username", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "background"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "categories", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "users"
end
