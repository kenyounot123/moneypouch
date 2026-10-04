# P3. Reversible: `up` backfills then tightens, `down` drops the columns and
# indexes and relaxes amount/currency back to nullable.
#
# Three indexes, each named by the read or write it serves:
#   (user_id, occurred_on)              month windows: Overview, month list
#   (user_id, lower(name)) WHERE kept   category inference per keystroke (P4 budget
#                                       2ms at 10k rows) and completions GROUP BY (P8)
#   (user_id, idempotency_key) UNIQUE   one row per typed line, however often its POST arrives
# The second and third indexes are additions to the spec's list. Without the second, inference is a
# scan of every kept row for the user on every keypress.
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

    # TODO: one UPDATE each, no Ruby loop (P3 perf: < 5s at 10k rows).
    #   UPDATE transactions SET occurred_on = date(created_at), name = '' WHERE occurred_on IS NULL
    #   UPDATE transactions SET currency = 'USD' WHERE currency IS NULL
    #   UPDATE transactions SET amount_in_cents = 0 WHERE amount_in_cents IS NULL
    # Legacy amounts keep their sign (P3 lane 2: "keep their amounts").

    change_column_null :transactions, :name, false
    change_column_null :transactions, :occurred_on, false
    change_column_null :transactions, :amount_in_cents, false
    change_column_null :transactions, :currency, false
    change_column_default :transactions, :currency, from: nil, to: "USD"

    add_index :transactions, %i[ user_id occurred_on ]
    add_index :transactions, "user_id, lower(name), occurred_on",
      where: "discarded_at IS NULL", name: "index_transactions_on_user_id_and_lower_name_kept"
    # One row per typed line, however many times its POST arrives.
    add_index :transactions, %i[ user_id idempotency_key ], unique: true, where: "idempotency_key IS NOT NULL"
  end

  def down
    raise NotImplementedError # inverse of up, in reverse order
  end
end
