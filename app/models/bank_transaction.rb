class BankTransaction < ApplicationRecord
  PAIR_WINDOW = 5

  belongs_to :bank_account
  belongs_to :simplefin_sync, class_name: "Simplefin::Sync"
  belongs_to :transfer_partner, class_name: "BankTransaction", optional: true

  delegate :full_name, to: :bank_account, prefix: true

  scope :unmatched, -> { where(matched: false) }
  scope :unpaired, -> { where(transfer_partner_id: nil) }
  scope :unmerged, -> { where.not(id: Transaction::DuplicateAnswer.same.select(:bank_transaction_id)) }

  def self.count_by_name
    unmatched.where(transaction_id: Transaction.kept.select(:id)).group(:name_key).count
  end

  def self.partner_for(amount_in_cents, currency, date, other_than:)
    unless amount_in_cents.zero?
      unmatched.unpaired
        .where.not(bank_account: other_than)
        .where(amount_in_cents: -amount_in_cents, occurred_on: (date - PAIR_WINDOW)..(date + PAIR_WINDOW))
        .where(transaction_id: Transaction.pairable.where(currency:).select(:id))
        .min_by { |candidate| [ (candidate.occurred_on - date).abs, candidate.id ] }
    end
  end

  def self.pair_up(bank_transactions, others)
    unpaired = bank_transactions.sort_by(&:id)
    waiting = others.to_a

    pairs = %i[ same_posting? same_day? ].flat_map do |same|
      waiting.dup.filter_map do |other|
        copy = unpaired.find { |bank_transaction| bank_transaction.public_send(same, other) }

        if copy
          [ unpaired.delete(copy), waiting.delete(other) ]
        end
      end
    end

    pairs + waiting.filter_map do |other|
      near = unpaired.select { |bank_transaction| bank_transaction.day_apart?(other) }

      if near.one? && waiting.one? { |rest| near.first.day_apart?(rest) }
        [ near.first, other ]
      end
    end
  end

  def name
    BankTransaction::Name.new(payee:, description:)
  end

  def same_posting?(other)
    posted_on_both?(other) && posted_at == other.posted_at && same_amount_and_name?(other)
  end

  def same_day?(other)
    alike_without_posted_time?(other) && occurred_on == other.occurred_on
  end

  def day_apart?(other)
    alike_without_posted_time?(other) && (occurred_on - other.occurred_on).abs == 1
  end

  def absorb(copy)
    if copy.paired? && paired?
      copy.unpair
    end

    partner = copy.transfer_partner
    copy.destroy!
    linked_transaction.absorb(copy.linked_transaction) if copy.unmatched?
    update!(external_id: copy.external_id, posted_at: copy.posted_at || posted_at)
    pair_with(partner) if partner
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
    partner.linked_transaction.then { |transaction| transaction.update!(categorization: transaction.user.rule_for(partner.name)&.categorization || Transaction::Categorization.none) }
  end

  def linked_transaction
    Transaction.find(transaction_id)
  end

  private
    def posted_on_both?(other)
      posted_at.present? && other.posted_at.present?
    end

    def alike_without_posted_time?(other)
      !posted_on_both?(other) && same_amount_and_name?(other)
    end

    def same_amount_and_name?(other)
      [ amount_in_cents, name_key ] == [ other.amount_in_cents, other.name_key ]
    end
end
