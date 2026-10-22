class RenameBackgroundToThemeOnUsers < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :background, :theme

    up_only do
      execute "UPDATE users SET theme = 'light' WHERE theme IS NULL OR theme NOT IN ('light', 'dark')"
    end

    change_column_default :users, :theme, from: nil, to: "light"
    change_column_null :users, :theme, false
    add_check_constraint :users, "theme IN ('light', 'dark')", name: "theme_is_light_or_dark"
  end
end
