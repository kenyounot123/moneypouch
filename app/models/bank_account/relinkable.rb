module BankAccount::Relinkable
  extend ActiveSupport::Concern

  included do
    scope :reported, -> { where(missing_since: nil) }
    scope :missing, -> { synced.where.not(missing_since: nil) }
    scope :undecided, -> { pending.or(missing) }
  end

  class_methods do
    def note_missing(simplefin_accounts)
      synced.reported.where.not(external_id: simplefin_accounts.map(&:id)).update_all(missing_since: Time.current, updated_at: Time.current)
    end
  end

  def missing?
    synced? && missing_since.present?
  end

  def replacement
    if missing? && namesakes.missing.one? && last_added_at
      candidates = namesakes.reported.where(created_at: last_added_at..).limit(2).to_a

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
    bank_transactions.update_all(bank_account_id: bank_account.id)
    reload.destroy!
    bank_account.update!(external_id:, balance_in_cents:, error_message:, missing_since: nil, relinked_at: Time.current)
  end

  private
    def namesakes
      simplefin_access.bank_accounts.where(name:, institution:)
    end

    def last_added_at
      bank_transactions.maximum(:created_at)
    end

    def adopt_new_ids(simplefin_transactions)
      if relinked_at
        ids = simplefin_transactions.map(&:id)
        known = bank_transactions.where(external_id: ids).pluck(:external_id)
        renamed = bank_transactions.where(created_at: ..relinked_at).where.not(external_id: ids).order(:id).group_by { |bank_transaction| [ bank_transaction.amount_in_cents, bank_transaction.occurred_on ] }

        simplefin_transactions.uniq(&:id).reject { |simplefin_transaction| simplefin_transaction.id.in?(known) }.each do |simplefin_transaction|
          renamed[[ simplefin_transaction.amount_in_cents, simplefin_transaction.occurred_on ]]&.shift&.update!(external_id: simplefin_transaction.id)
        end
      end
    end
end
