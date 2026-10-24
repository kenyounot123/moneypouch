module Transaction::Bankable
  extend ActiveSupport::Concern

  MATCH_WINDOW = -5..1

  included do
    has_one :bank_transaction

    delegate :name, to: :bank_transaction, prefix: true

    scope :matchable, -> { where.missing(:bank_transaction) }
    # Transaction shadows ActiveRecord's #transaction, so BankTransaction can't belongs_to it. Every lookup
    # from bank rows to their transactions goes through these two scopes.
    scope :behind, ->(bank_transactions) { where(id: bank_transactions.select(:transaction_id)) }
    scope :typed_in, -> { where.not(id: BankTransaction.select(:transaction_id)) }
    scope :added_by_bank, -> { behind(BankTransaction.unmatched) }
    scope :needing_category, -> { kept.added_by_bank.uncategorized }
    scope :from_bank_account, ->(bank_account) { merge(bank_account.transactions) }
  end

  class_methods do
    def match_for(amount_in_cents, currency, date)
      matchable
        .where(amount_in_cents:, currency:, occurred_on: (date + MATCH_WINDOW.begin)..(date + MATCH_WINDOW.end))
        .min_by { |transaction| [ (transaction.occurred_on - date).abs, transaction.id ] }
    end

    def add_from_bank(simplefin_transaction, currency:, categorization:)
      create!(
        name: simplefin_transaction.name.to_s,
        amount_in_cents: simplefin_transaction.amount_in_cents,
        currency:,
        occurred_on: simplefin_transaction.occurred_on,
        categorization:
      )
    end
  end

  def bank_account_name
    bank_transaction&.bank_account_full_name
  end

  def from_bank?
    bank_transaction.present?
  end

  def added_by_bank?
    from_bank? && bank_transaction.unmatched?
  end

  def paired?
    from_bank? && bank_transaction.paired?
  end

  def paired_account_name
    bank_transaction.transfer_partner.bank_account_full_name
  end

  def needs_category?
    added_by_bank? && category_id.nil? && !transfer?
  end

  def offers_rule?
    added_by_bank? && !paired? && !categorization.none? && !user.remembers?(bank_transaction_name, categorization)
  end

  def make_rule
    if added_by_bank? && !categorization.none?
      user.remember(bank_transaction_name, categorization)
    end
  end

  def waiting_namesake_count
    user.transactions_named(bank_transaction_name.key).needing_category.count
  end
end
