class SplitModeFromThemeOnUsers < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :users, "theme IN ('light', 'dark')", name: "theme_is_light_or_dark"
    rename_column :users, :theme, :mode
    add_check_constraint :users, "mode IN ('light', 'dark')", name: "mode_is_light_or_dark"

    add_column :users, :theme, :string, default: "pouch", null: false
    add_check_constraint :users, "theme IN ('pouch', 'graphite', 'moss', 'tide', 'ember', 'rose', 'plum')", name: "theme_is_known"
  end
end
