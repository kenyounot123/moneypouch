class AddNameToBankAccountRules < ActiveRecord::Migration[8.1]
  def up
    add_column :bank_account_rules, :name, :string

    execute <<~SQL
      UPDATE bank_account_rules SET name = COALESCE((
        SELECT transactions.name FROM bank_transactions
        JOIN transactions ON transactions.id = bank_transactions.transaction_id
        WHERE bank_transactions.bank_account_id = bank_account_rules.bank_account_id
          AND bank_transactions.name_key = bank_account_rules.name_key
          AND bank_transactions.matched = FALSE
        ORDER BY bank_transactions.occurred_on DESC, bank_transactions.id DESC
        LIMIT 1
      ), name_key)
    SQL

    change_column_null :bank_account_rules, :name, false
  end

  def down
    remove_column :bank_account_rules, :name
  end
end
