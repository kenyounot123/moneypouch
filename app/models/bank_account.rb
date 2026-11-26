class BankAccount < ApplicationRecord
  include Relinkable

  belongs_to :simplefin_access, class_name: "Simplefin::Access"
  belongs_to :user, default: -> { simplefin_access.user }
  has_many :bank_transactions, dependent: :destroy

  enum :status, %w[ pending synced skipped ].index_by(&:itself)

  scope :not_syncing, -> { pending.or(skipped) }

  def self.refresh(simplefin_account)
    sent_as(simplefin_account.id).tap do |bank_account|
      bank_account.update!(
        name: simplefin_account.name,
        institution: simplefin_account.institution,
        currency: simplefin_account.currency,
        balance_in_cents: simplefin_account.balance_in_cents,
        balance_date: simplefin_account.balance_date,
        error_message: simplefin_account.error_message
      )
    end
  end

  def full_name
    if institution.blank? || names_bank?
      name
    else
      "#{institution} #{name}"
    end
  end

  def start_syncing(from:)
    update!(status: :synced, starts_on: from)
  end

  def sync_recent_history
    start_syncing(from: simplefin_access.longest_history_start)
    simplefin_access.sync_later
  end

  def resume
    unless replacing?
      bank_transactions.doubt_ids
      sync_recent_history
    end
  end

  def short_history?
    starts_on > simplefin_access.longest_history_start
  end

  def skip
    update!(status: :skipped)
  end

  def transactions
    Transaction.behind(bank_transactions)
  end

  def add_transactions(simplefin_transactions, sync:)
    if synced?
      note_posted_times(simplefin_transactions)
      adopt_new_ids(simplefin_transactions)

      simplefin_transactions.each do |simplefin_transaction|
        if simplefin_transaction.occurred_on >= starts_on
          add_transaction(simplefin_transaction, sync:)
        end
      end
    end
  end

  private
    def names_bank?
      words = ->(text) { text.downcase.scan(/\p{Alnum}{3,}/) }
      words.(name).intersect?(words.(institution))
    end

    def owner
      simplefin_access.user
    end

    def partner_for(simplefin_transaction, sync:)
      unless sync.rule_book.categorized?(simplefin_transaction.name)
        owner.bank_transactions.partner_for(simplefin_transaction.amount_in_cents, currency, simplefin_transaction.occurred_on, other_than: self)
      end
    end

    def add_new(simplefin_transaction, partner:, sync:)
      owner.transactions.add_from_bank(simplefin_transaction, currency:, categorization: sync.rule_book.categorization_for(simplefin_transaction.name, paired: partner.present?))
    end

    def add_transaction(simplefin_transaction, sync:)
      add_unless_present(simplefin_transaction, sync:)
    rescue ActiveRecord::RecordNotUnique
      add_unless_present(simplefin_transaction, sync:)
    end

    def add_unless_present(simplefin_transaction, sync:)
      unless bank_transactions.exists?(external_id: simplefin_transaction.id)
        transaction do
          match = owner.transactions.match_for(simplefin_transaction.amount_in_cents, currency, simplefin_transaction.occurred_on)
          partner = partner_for(simplefin_transaction, sync:) unless match

          bank_transaction = bank_transactions.create!(
            simplefin_sync: sync,
            transaction_id: (match || add_new(simplefin_transaction, partner:, sync:)).id,
            matched: match.present?,
            external_id: simplefin_transaction.id,
            amount_in_cents: simplefin_transaction.amount_in_cents,
            occurred_on: simplefin_transaction.occurred_on,
            posted_at: simplefin_transaction.posted_at,
            transacted_at: simplefin_transaction.transacted_at,
            description: simplefin_transaction.description,
            payee: simplefin_transaction.payee,
            name_key: simplefin_transaction.name.key
          )

          bank_transaction.pair_with(partner) if partner
        end
      end
    end
end
