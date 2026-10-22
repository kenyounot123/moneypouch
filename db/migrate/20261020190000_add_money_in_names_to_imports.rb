class AddMoneyInNamesToImports < ActiveRecord::Migration[8.1]
  def change
    add_column :imports, :money_in_names, :text, null: false, default: "{}"
  end
end
