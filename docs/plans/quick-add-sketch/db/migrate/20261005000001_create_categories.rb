# P3. Categories are per user and unique ignoring ASCII case.
# SQLite lower() folds ASCII only, so every Ruby lookup must use
# `name.downcase(:ascii)` to agree with this index (see Category.named).
class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.timestamps
    end

    add_index :categories, "user_id, lower(name)", unique: true, name: "index_categories_on_user_id_and_lower_name"
  end
end
