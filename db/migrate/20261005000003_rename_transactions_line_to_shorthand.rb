class RenameTransactionsLineToShorthand < ActiveRecord::Migration[8.1]
  def change
    rename_column :transactions, :line, :shorthand
  end
end
