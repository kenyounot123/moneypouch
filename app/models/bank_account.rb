class BankAccount < ApplicationRecord
  belongs_to :simplefin_access, class_name: "Simplefin::Access"
  belongs_to :user, default: -> { simplefin_access.user }
  has_many :bank_transactions, dependent: :destroy

  enum :status, %w[ pending synced skipped ].index_by(&:itself)

  def self.refresh(simplefin_account)
    find_or_initialize_by(external_id: simplefin_account.id).tap do |bank_account|
      bank_account.update!(
        name: simplefin_account.name,
        institution: simplefin_account.institution,
        currency: simplefin_account.currency,
        balance_in_cents: simplefin_account.balance_in_cents,
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

  def start_syncing(from: Date.current)
    update!(status: :synced, starts_on: from)
  end

  def skip
    update!(status: :skipped)
  end

  def transactions
    Transaction.behind(bank_transactions)
  end

  def add_transactions(simplefin_transactions, sync:)
    if synced?
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

    # The access's user, which one sync shares across its accounts, so their rules load once.
    def owner
      simplefin_access.user
    end

    # A rule that gives the name a category decides the row. A rule that marks it a transfer still lets it find its other half.
    def partner_for(simplefin_transaction)
      unless owner.rule_for(simplefin_transaction.name)&.category
        owner.bank_transactions.partner_for(simplefin_transaction.amount_in_cents, currency, simplefin_transaction.occurred_on, other_than: self)
      end
    end

    def add_new(simplefin_transaction, partner:)
      owner.transactions.add_from_bank(simplefin_transaction, currency:, categorization: owner.categorization_for(simplefin_transaction.name, paired: partner.present?))
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
          partner = partner_for(simplefin_transaction) unless match

          bank_transaction = bank_transactions.create!(
            simplefin_sync: sync,
            transaction_id: (match || add_new(simplefin_transaction, partner:)).id,
            matched: match.present?,
            external_id: simplefin_transaction.id,
            amount_in_cents: simplefin_transaction.amount_in_cents,
            occurred_on: simplefin_transaction.occurred_on,
            description: simplefin_transaction.description,
            payee: simplefin_transaction.payee,
            name_key: simplefin_transaction.name.key
          )

          bank_transaction.pair_with(partner) if partner
        end
      end
    end
end
