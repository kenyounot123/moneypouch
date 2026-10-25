class PairBankTransfers < ActiveRecord::Migration[8.1]
  PAIR_WINDOW_DAYS = 5

  def up
    add_reference :bank_transactions, :transfer_partner, index: { unique: true },
      foreign_key: { to_table: :bank_transactions, on_delete: :nullify }

    pair_existing_rows
  end

  def down
    remove_reference :bank_transactions, :transfer_partner, foreign_key: { to_table: :bank_transactions }
  end

  # The sync's pairing rule applied to rows already there, so a row pairs only with the one that also ranks
  # it first. Rows arriving one at a time pick the closest in time, but here every row is waiting at once and
  # taking the best for one could steal another's only partner. Safe to run twice: a paired row is no longer eligible.
  def pair_existing_rows
    execute "DROP TABLE IF EXISTS temp.transfer_candidates"
    execute "DROP TABLE IF EXISTS temp.transfer_pairs"

    # Joined through an index on the plain magnitude, since a self-join that cannot use an index grows with the square
    # of the row count and holds the write lock long enough for the running app's writes to time out.
    execute <<~SQL
      CREATE TEMP TABLE transfer_candidates AS
      SELECT bank_transactions.id, bank_transactions.bank_account_id, bank_transactions.amount_in_cents,
             ABS(bank_transactions.amount_in_cents) AS magnitude,
             julianday(bank_transactions.occurred_on) AS day, transactions.currency, bank_accounts.user_id
      FROM bank_transactions
      JOIN transactions ON transactions.id = bank_transactions.transaction_id
      JOIN bank_accounts ON bank_accounts.id = bank_transactions.bank_account_id
      WHERE bank_transactions.matched = FALSE
        AND bank_transactions.transfer_partner_id IS NULL
        AND bank_transactions.amount_in_cents <> 0
        AND transactions.discarded_at IS NULL
        AND transactions.category_id IS NULL
    SQL
    execute "CREATE INDEX temp.transfer_candidates_by_amount ON transfer_candidates (user_id, currency, magnitude, day)"

    execute <<~SQL
      CREATE TEMP TABLE transfer_pairs (id INTEGER PRIMARY KEY, partner_id INTEGER NOT NULL)
    SQL

    execute <<~SQL
      WITH ranked AS (
        SELECT money_out.id AS out_id, money_in.id AS in_id,
               ROW_NUMBER() OVER (PARTITION BY money_out.id ORDER BY ABS(money_out.day - money_in.day), money_in.id) AS best_in_for_out,
               ROW_NUMBER() OVER (PARTITION BY money_in.id ORDER BY ABS(money_out.day - money_in.day), money_out.id) AS best_out_for_in
        FROM transfer_candidates money_out
        JOIN transfer_candidates money_in
          ON money_in.user_id = money_out.user_id
          AND money_in.currency = money_out.currency
          AND money_in.magnitude = money_out.magnitude
          AND money_in.day BETWEEN money_out.day - #{PAIR_WINDOW_DAYS} AND money_out.day + #{PAIR_WINDOW_DAYS}
          AND money_in.amount_in_cents > 0
          AND money_in.bank_account_id <> money_out.bank_account_id
        WHERE money_out.amount_in_cents < 0
      ),
      mutual AS (
        SELECT out_id, in_id FROM ranked WHERE best_in_for_out = 1 AND best_out_for_in = 1
      )
      INSERT INTO transfer_pairs (id, partner_id)
      SELECT out_id, in_id FROM mutual UNION ALL SELECT in_id, out_id FROM mutual
    SQL

    execute <<~SQL
      UPDATE bank_transactions
      SET transfer_partner_id = (SELECT partner_id FROM transfer_pairs WHERE transfer_pairs.id = bank_transactions.id)
      WHERE id IN (SELECT id FROM transfer_pairs)
    SQL

    execute <<~SQL
      UPDATE transactions
      SET transfer = TRUE
      WHERE id IN (SELECT transaction_id FROM bank_transactions WHERE id IN (SELECT id FROM transfer_pairs))
    SQL

    execute "DROP TABLE transfer_pairs"
    execute "DROP TABLE transfer_candidates"
  end
end
