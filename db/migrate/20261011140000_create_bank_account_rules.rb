class CreateBankAccountRules < ActiveRecord::Migration[8.1]
  def change
    create_table :bank_account_rules do |t|
      t.references :bank_account, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.string :name_key, null: false
      t.references :category, foreign_key: { on_delete: :cascade }
      t.boolean :transfer, default: false, null: false
      t.timestamps

      t.index [ :bank_account_id, :name_key ], unique: true
      t.check_constraint "(category_id IS NULL) = transfer", name: "rule_is_a_category_or_a_transfer"
    end
  end
end
