class CreateDuplicateAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :duplicate_answers do |t|
      t.references :typed_transaction, null: false, index: false, foreign_key: { to_table: :transactions, on_delete: :cascade }
      t.references :bank_transaction, null: false, foreign_key: { on_delete: :cascade }
      t.boolean :same, null: false
      t.timestamps

      t.index %i[ typed_transaction_id bank_transaction_id ], unique: true
      t.index :bank_transaction_id, unique: true, where: "same", name: "index_duplicate_answers_one_same_per_bank_row"
    end
  end
end
