module BankAccount::Relinkable
  extend ActiveSupport::Concern

  included do
    scope :reported, -> { where(missing_since: nil) }
    scope :missing, -> { synced.where.not(missing_since: nil) }
    scope :undecided, -> { pending.or(missing) }

    has_many :former_ids, class_name: "BankAccount::FormerId", dependent: :delete_all
  end

  class_methods do
    def note_report(simplefin_accounts)
      ids = simplefin_accounts.map(&:id)

      if ids.any?
        where(external_id: ids).update_all(reported_at: Time.current, missing_since: nil)
        reported.where.not(external_id: ids).where.not(id: sent_as_former(ids)).update_all(missing_since: Time.current)
      end
    end

    def freshest(simplefin_accounts)
      outdated = sent_as_former(simplefin_accounts.map(&:id)).distinct.flat_map { |bank_account| bank_account.outdated_in(simplefin_accounts) }
      simplefin_accounts - outdated
    end

    def sent_as_former(ids)
      joins(:former_ids).where(bank_account_former_ids: { external_id: ids })
    end

    def sent_as(external_id)
      former = joins(:former_ids).find_by(bank_account_former_ids: { external_id: })

      if former
        former.tap { |bank_account| bank_account.relink_back(external_id) }
      else
        find_or_initialize_by(external_id:)
      end
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

  def replacement_choices
    if missing?
      simplefin_access.bank_accounts.pending.reported.where(institution:).order(:id)
    else
      BankAccount.none
    end
  end

  def replacement_for(id)
    if id.present?
      replacement_choices.find_by(id:)
    else
      replacement
    end
  end

  def replacing?
    simplefin_access.replacements.include?(self)
  end

  def carry_on_with_replacement(replacement_id = nil)
    with_lock do
      replacement_for(replacement_id)&.hand_over_to(self)
    end

    simplefin_access.sync_later
  end

  def hand_over_to(bank_account)
    bank_account.take_over(bank_transactions)
    reload.destroy!
    bank_account.relink(external_id, balance_in_cents:, balance_date:, error_message:, reported_at:, missing_since: nil)
  end

  def relink(external_id, **attributes)
    former_ids.find_or_initialize_by(external_id:).update!(external_id: self.external_id)
    update!(external_id:, **attributes)
  end

  def relink_back(external_id)
    bank_transactions.flip_doubt
    relink(external_id)
  end

  def outdated_in(simplefin_accounts)
    current = simplefin_accounts.find { |simplefin_account| simplefin_account.id == external_id }
    ids = former_ids.pluck(:external_id)
    formers = simplefin_accounts.select { |simplefin_account| simplefin_account.id.in?(ids) }
    newest = formers.max_by(&:balance_date)

    if newest.balance_date > (current&.balance_date || balance_date)
      formers - [ newest ] + [ current ].compact
    else
      formers
    end
  end

  def take_over(others)
    if bank_transactions.exists?(external_id: others.select(:external_id))
      copies = copies_by_id(others)
    else
      copies = BankTransaction.pair_up(bank_transactions, others)
      bank_transactions.where.not(id: copies.map(&:first)).doubt_ids
    end

    copies.each { |bank_transaction, copy| bank_transaction.absorb(copy) }
    others.update_all(bank_account_id: id)
  end

  private
    def copies_by_id(others)
      mine = bank_transactions.where(external_id: others.select(:external_id)).index_by(&:external_id)

      others.select { |other| mine.key?(other.external_id) }.map { |other| [ mine[other.external_id], other ] }
    end

    def namesakes
      simplefin_access.bank_accounts.where(name:, institution:)
    end

    def adopt_new_ids(simplefin_transactions)
      ids = simplefin_transactions.map(&:id)
      in_doubt = bank_transactions.with_id_in_doubt

      if in_doubt.exists?(external_id: ids)
        in_doubt.trust_ids
      elsif in_doubt.exists?
        known = bank_transactions.where(external_id: ids).pluck(:external_id)
        unknown = simplefin_transactions.uniq(&:id).reject { |simplefin_transaction| simplefin_transaction.id.in?(known) }

        BankTransaction.pair_up(in_doubt, unknown).each { |bank_transaction, simplefin_transaction| bank_transaction.adopt(simplefin_transaction) }
        in_doubt.where(occurred_on: ...simplefin_access.history_start.to_date - BankTransaction::PAIR_WINDOW).trust_ids
      end
    end

    def note_posted_times(simplefin_transactions)
      unposted = bank_transactions.where(external_id: simplefin_transactions.map(&:id), posted_at: nil).index_by(&:external_id)

      simplefin_transactions.each do |simplefin_transaction|
        unposted.delete(simplefin_transaction.id)&.note_times(simplefin_transaction)
      end
    end
end
