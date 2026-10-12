class AddNoteToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :note, :text
  end
end
