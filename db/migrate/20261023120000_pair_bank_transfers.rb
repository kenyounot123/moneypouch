class PairBankTransfers < ActiveRecord::Migration[8.1]
  def up
    add_reference :bank_transactions, :transfer_partner, index: { unique: true },
      foreign_key: { to_table: :bank_transactions, on_delete: :nullify }
  end

  def down
    remove_reference :bank_transactions, :transfer_partner, foreign_key: { to_table: :bank_transactions }
  end
end
