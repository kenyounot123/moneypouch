module Transaction::Mergeable
  extend ActiveSupport::Concern

  included do
    has_many :duplicate_answers, foreign_key: :typed_transaction_id, inverse_of: :typed_transaction

    scope :possibly_repeating, -> { counted.typed_in.where.not(amount_in_cents: 0) }
    scope :possibly_repeated, -> { counted.added_by_bank.joins(:bank_transaction).merge(BankTransaction.unmerged) }
  end

  def merge_into(bank_rows)
    answer_duplicate(bank_rows, same: true)
    bank_rows.each { |bank_row| bank_row.fill_in_from(self) }
    discard
  end

  def keep_apart_from(bank_rows)
    answer_duplicate(bank_rows, same: false)
  end

  def absorb(copy)
    fill_in_from(copy)

    if discarded_at && copy.discarded_at.nil?
      update!(discarded_at: nil)
    end

    copy.destroy!
  end

  def fill_in_from(typed)
    if needs_category?
      categorize(typed.categorization)
    end

    if note.blank?
      update!(note: typed.note)
    end
  end

  private
    def answer_duplicate(bank_rows, same:)
      duplicate_answers.create!(bank_rows.map { |bank_row| { bank_transaction_id: bank_row.bank_transaction_id, same: } })
    end
end
