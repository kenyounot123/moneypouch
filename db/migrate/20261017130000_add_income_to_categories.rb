class AddIncomeToCategories < ActiveRecord::Migration[8.1]
  def up
    add_column :categories, :income, :boolean, default: false, null: false

    execute "UPDATE categories SET income = TRUE WHERE lower(name) = 'income'"

    execute <<~SQL
      INSERT INTO categories (user_id, name, income, created_at, updated_at)
      SELECT users.id, 'Income', TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM users
      WHERE NOT EXISTS (SELECT 1 FROM categories WHERE categories.user_id = users.id AND lower(categories.name) = 'income')
    SQL

    execute <<~SQL
      UPDATE transactions
      SET category_id = (SELECT id FROM categories WHERE categories.user_id = transactions.user_id AND lower(categories.name) = 'income')
      WHERE category_id IS NULL AND NOT transfer AND amount_in_cents > 0
        AND id NOT IN (SELECT transaction_id FROM bank_transactions WHERE NOT matched)
    SQL
  end

  def down
    remove_column :categories, :income
  end
end
