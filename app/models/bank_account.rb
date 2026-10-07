class BankAccount < ApplicationRecord
  belongs_to :user
  belongs_to :simplefin_access, class_name: "Simplefin::Access"
  has_many :bank_transactions, dependent: :destroy

  enum :status, %w[ pending synced skipped ].index_by(&:itself)

  def self.refresh(simplefin_account, user:)
    find_or_initialize_by(external_id: simplefin_account.id).tap do |bank_account|
      bank_account.update!(
        user:,
        name: simplefin_account.name,
        institution: simplefin_account.institution,
        currency: simplefin_account.currency,
        balance_in_cents: simplefin_account.balance_in_cents,
        error_message: simplefin_account.error_message
      )
    end
  end

  def start_syncing(from: Date.current)
    update!(status: :synced, starts_on: from)
  end

  def skip
    update!(status: :skipped)
  end

  def import(simplefin_transactions, sync:)
    if synced?
      simplefin_transactions.each do |simplefin_transaction|
        if simplefin_transaction.occurred_on >= starts_on
          import_transaction(simplefin_transaction, sync:)
        end
      end
    end
  end

  private
    def import_transaction(simplefin_transaction, sync:)
      import_unless_present(simplefin_transaction, sync:)
    rescue ActiveRecord::RecordNotUnique
      import_unless_present(simplefin_transaction, sync:)
    end

    def import_unless_present(simplefin_transaction, sync:)
      unless bank_transactions.exists?(external_id: simplefin_transaction.id)
        transaction do
          match = user.transactions.match_for(simplefin_transaction.amount_in_cents, currency, simplefin_transaction.occurred_on)

          bank_transactions.create!(
            simplefin_sync: sync,
            transaction_id: (match || user.transactions.import(simplefin_transaction, currency:)).id,
            matched: match.present?,
            external_id: simplefin_transaction.id,
            amount_in_cents: simplefin_transaction.amount_in_cents,
            occurred_on: simplefin_transaction.occurred_on,
            description: simplefin_transaction.description,
            payee: simplefin_transaction.payee
          )
        end
      end
    end
end
