class MoveRulesToUsers < ActiveRecord::Migration[8.1]
  def up
    create_table :rules do |t|
      t.references :user, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.string :name_key, null: false
      t.string :name, null: false
      t.references :category, foreign_key: { on_delete: :cascade }
      t.boolean :transfer, default: false, null: false
      t.timestamps

      t.index [ :user_id, :name_key ], unique: true
      t.check_constraint "(category_id IS NULL) = transfer", name: "rule_is_a_category_or_a_transfer"
    end

    # One rule per user and name. When accounts disagree, the most recently updated rule wins.
    execute <<~SQL
      INSERT INTO rules (user_id, name_key, name, category_id, transfer, created_at, updated_at)
      SELECT accounts.user_id, r.name_key, r.name, r.category_id, r.transfer, r.created_at, r.updated_at
      FROM bank_account_rules r
      JOIN bank_accounts accounts ON accounts.id = r.bank_account_id
      WHERE r.id = (
        SELECT r2.id FROM bank_account_rules r2
        JOIN bank_accounts a2 ON a2.id = r2.bank_account_id
        WHERE a2.user_id = accounts.user_id AND r2.name_key = r.name_key
        ORDER BY r2.updated_at DESC, r2.id DESC
        LIMIT 1
      )
    SQL

    # A rule now spans accounts, so fill the waiting rows it would have filled had it always been the user's.
    execute <<~SQL
      UPDATE transactions
      SET category_id = (
            SELECT rules.category_id FROM rules
            JOIN bank_transactions ON bank_transactions.name_key = rules.name_key
            WHERE bank_transactions.transaction_id = transactions.id AND rules.user_id = transactions.user_id
          ),
          transfer = (
            SELECT rules.transfer FROM rules
            JOIN bank_transactions ON bank_transactions.name_key = rules.name_key
            WHERE bank_transactions.transaction_id = transactions.id AND rules.user_id = transactions.user_id
          )
      WHERE transactions.discarded_at IS NULL
        AND transactions.category_id IS NULL
        AND transactions.transfer = FALSE
        AND EXISTS (
          SELECT 1 FROM rules
          JOIN bank_transactions ON bank_transactions.name_key = rules.name_key
          WHERE bank_transactions.transaction_id = transactions.id
            AND bank_transactions.matched = FALSE
            AND rules.user_id = transactions.user_id
        )
    SQL

    drop_table :bank_account_rules
  end

  def down
    create_table :bank_account_rules do |t|
      t.references :bank_account, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.string :name_key, null: false
      t.string :name, null: false
      t.references :category, foreign_key: { on_delete: :cascade }
      t.boolean :transfer, default: false, null: false
      t.timestamps

      t.index [ :bank_account_id, :name_key ], unique: true
      t.check_constraint "(category_id IS NULL) = transfer", name: "rule_is_a_category_or_a_transfer"
    end

    execute <<~SQL
      INSERT INTO bank_account_rules (bank_account_id, name_key, name, category_id, transfer, created_at, updated_at)
      SELECT accounts.id, rules.name_key, rules.name, rules.category_id, rules.transfer, rules.created_at, rules.updated_at
      FROM rules
      JOIN bank_accounts accounts ON accounts.user_id = rules.user_id
    SQL

    drop_table :rules
  end
end
