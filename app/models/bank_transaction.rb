class BankTransaction < ApplicationRecord
  PAIR_WINDOW = 5

  belongs_to :bank_account
  belongs_to :simplefin_sync, class_name: "Simplefin::Sync"
  belongs_to :transfer_partner, class_name: "BankTransaction", optional: true

  delegate :full_name, to: :bank_account, prefix: true

  scope :unmatched, -> { where(matched: false) }
  scope :unpaired, -> { where(transfer_partner_id: nil) }

  def self.count_by_name
    unmatched.where(transaction_id: Transaction.kept.select(:id)).group(:name_key).count
  end

  # The other half of a card payment or account transfer: money of the same size going the other way, in
  # another account, that the bank added and nobody has categorized yet.
  def self.partner_for(amount_in_cents, currency, date, other_than:)
    unless amount_in_cents.zero?
      unmatched.unpaired
        .where.not(bank_account: other_than)
        .where(amount_in_cents: -amount_in_cents, occurred_on: (date - PAIR_WINDOW)..(date + PAIR_WINDOW))
        .where(transaction_id: Transaction.needing_category.where(currency:).select(:id))
        .min_by { |candidate| [ (candidate.occurred_on - date).abs, candidate.id ] }
    end
  end

  def name
    BankTransaction::Name.new(payee:, description:)
  end

  def unmatched?
    !matched?
  end

  def paired?
    transfer_partner_id.present?
  end

  def pair_with(partner)
    update!(transfer_partner: partner)
    partner.update!(transfer_partner: self)
    [ self, partner ].each { |bank_transaction| bank_transaction.linked_transaction.update!(categorization: Transaction::Categorization.transfer) }
  end

  def unpair
    partner = transfer_partner
    update!(transfer_partner: nil)
    partner.update!(transfer_partner: nil)
    partner.linked_transaction.update!(categorization: Transaction::Categorization.none)
  end

  # Transaction shadows ActiveRecord's #transaction, so there is no belongs_to; see Transaction::Bankable.
  def linked_transaction
    Transaction.find(transaction_id)
  end
end
