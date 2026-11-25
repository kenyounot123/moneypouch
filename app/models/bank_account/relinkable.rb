module BankAccount::Relinkable
  extend ActiveSupport::Concern

  included do
    scope :reported, -> { where(missing_since: nil) }
    scope :missing, -> { synced.where.not(missing_since: nil) }
    scope :undecided, -> { pending.or(missing) }
  end

  class_methods do
    def note_report(simplefin_accounts)
      ids = simplefin_accounts.map(&:id)

      where(external_id: ids).update_all(reported_at: Time.current, missing_since: nil)
      reported.where.not(external_id: ids).update_all(missing_since: Time.current)
    end
  end

  def missing?
    synced? && missing_since.present?
  end

  def replacement
    if missing? && namesakes.missing.one?
      candidates = namesakes.reported.where("created_at > ?", reported_at).limit(2).to_a

      if candidates.one?
        candidates.first
      end
    end
  end

  def replacing?
    simplefin_access.replacements.include?(self)
  end

  def carry_on_with_replacement
    with_lock do
      replacement&.hand_over_to(self)
    end

    simplefin_access.sync_later
  end

  def hand_over_to(bank_account)
    bank_account.take_over(bank_transactions)
    reload.destroy!
    bank_account.update!(external_id:, balance_in_cents:, error_message:, reported_at:, missing_since: nil, relinked_at: Time.current)
  end

  def take_over(others)
    pair_with_copies(others).each { |bank_transaction, copy| bank_transaction.absorb(copy) }
    others.update_all(bank_account_id: id)
  end

  private
    def pair_with_copies(others)
      same_ids = bank_transactions.where(external_id: others.select(:external_id)).index_by(&:external_id)
      by_id, rest = others.partition { |other| same_ids.key?(other.external_id) }

      by_id.map { |other| [ same_ids[other.external_id], other ] } + BankTransaction.pair_up(bank_transactions.where.not(id: same_ids.values), rest)
    end

    def namesakes
      simplefin_access.bank_accounts.where(name:, institution:)
    end

    def adopt_new_ids(simplefin_transactions)
      if relinked_at
        ids = simplefin_transactions.map(&:id)
        known = bank_transactions.where(external_id: ids).pluck(:external_id)
        renamed = bank_transactions.where(created_at: ..relinked_at).where.not(external_id: ids)
        unknown = simplefin_transactions.uniq(&:id).reject { |simplefin_transaction| simplefin_transaction.id.in?(known) }

        BankTransaction.pair_up(renamed, unknown).each do |bank_transaction, simplefin_transaction|
          bank_transaction.update!(external_id: simplefin_transaction.id, posted_at: simplefin_transaction.posted_at)
        end
      end
    end

    def note_posted_times(simplefin_transactions)
      unposted = bank_transactions.where(external_id: simplefin_transactions.map(&:id), posted_at: nil).index_by(&:external_id)

      simplefin_transactions.each do |simplefin_transaction|
        unposted.delete(simplefin_transaction.id)&.update!(posted_at: simplefin_transaction.posted_at)
      end
    end
end
