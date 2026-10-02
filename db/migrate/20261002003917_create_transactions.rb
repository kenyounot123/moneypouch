class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      t.integer :amount_in_cents
      t.string :currency

      t.timestamps
    end
  end
end
