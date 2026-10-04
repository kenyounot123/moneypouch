class ShapeTransactions < ActiveRecord::Migration[8.1]
  def up
    change_table :transactions do |t|
      t.string :name
      t.date :occurred_on
      t.references :category, foreign_key: true, index: false
      t.text :line
      t.datetime :discarded_at
      t.string :idempotency_key
    end

    execute "UPDATE transactions SET name = '', occurred_on = date(created_at)"
    execute "UPDATE transactions SET amount_in_cents = coalesce(amount_in_cents, 0), currency = coalesce(currency, 'USD')"

    change_column_null :transactions, :name, false
    change_column_null :transactions, :occurred_on, false
    change_column_null :transactions, :amount_in_cents, false
    change_column_null :transactions, :currency, false
    change_column_default :transactions, :currency, from: nil, to: "USD"

    remove_index :transactions, :user_id
    add_index :transactions, %i[ user_id occurred_on ]
    add_index :transactions, "user_id, lower(name), occurred_on",
      where: "discarded_at IS NULL", name: "index_transactions_on_user_id_and_lower_name_kept"
    add_index :transactions, %i[ user_id idempotency_key ], unique: true, where: "idempotency_key IS NOT NULL"
  end

  def down
    remove_index :transactions, %i[ user_id idempotency_key ]
    remove_index :transactions, name: "index_transactions_on_user_id_and_lower_name_kept"
    remove_index :transactions, %i[ user_id occurred_on ]
    add_index :transactions, :user_id

    change_column_default :transactions, :currency, from: "USD", to: nil
    change_column_null :transactions, :currency, true
    change_column_null :transactions, :amount_in_cents, true

    change_table :transactions do |t|
      t.remove :idempotency_key, :discarded_at, :line
      t.remove_references :category, foreign_key: true, index: false
      t.remove :occurred_on, :name
    end
  end
end
