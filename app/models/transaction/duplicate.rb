class Transaction::Duplicate < Data.define(:typed, :bank_rows)
  def merge
    typed.merge_into(bank_rows)
  end

  def keep_both
    typed.keep_apart_from(bank_rows)
  end

  def several?
    bank_rows.many?
  end

  def total_in_cents
    bank_rows.sum(&:amount_in_cents)
  end

  def bank_transaction_ids
    bank_rows.map(&:bank_transaction_id)
  end
end
