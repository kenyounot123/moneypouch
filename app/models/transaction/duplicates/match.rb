class Transaction::Duplicates::Match < Data.define(:typed, :bank_rows)
  def rank
    [ bank_rows.size, bank_rows.sum { |bank_row| bank_row.days_from(typed) }, *ids ]
  end

  def ids
    [ typed.id, *bank_rows.map(&:id) ]
  end

  def between?(transaction_id, bank_transaction_ids)
    typed.id == transaction_id && bank_rows.map(&:bank_transaction_id).sort == bank_transaction_ids.sort
  end
end
