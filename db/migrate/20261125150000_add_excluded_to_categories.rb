class AddExcludedToCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :excluded, :boolean, default: false, null: false
  end
end
