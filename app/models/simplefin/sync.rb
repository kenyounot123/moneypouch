class Simplefin::Sync < ApplicationRecord
  STALE_AFTER = 15.minutes

  belongs_to :access
  has_many :bank_transactions, foreign_key: :simplefin_sync_id, inverse_of: :simplefin_sync, dependent: :destroy

  scope :running, -> { where(finished_at: nil) }
  scope :finished, -> { where.not(finished_at: nil) }
  scope :succeeded, -> { finished.where(failure: nil) }
  scope :answered, -> { finished.where(failure: [ nil, "lapsed", "revoked" ]) }
  scope :recent, ->(within) { where(created_at: within.ago..) }
  scope :with_bank_transactions, -> { where.associated(:bank_transactions).distinct }

  def self.abandon_stale
    running.where(created_at: ...STALE_AFTER.ago).find_each(&:abandon)
  end

  def run_later
    Simplefin::SyncJob.perform_later(self)
  end

  def run_now
    return if finished?

    Time.use_zone(access.time_zone) do
      Transaction.broadcasting_once_for(access.user) { import }
    end
  end

  def abandon
    finish("abandoned")
  end

  def finished?
    finished_at.present?
  end

  def lapsed?
    failure == "lapsed"
  end

  def imported_count
    bank_transactions.imported.count
  end

  def matched_count
    bank_transactions.matched.count
  end

  def imported_transactions
    Transaction.where(id: bank_transactions.imported.select(:transaction_id))
  end

  private
    def import
      access.client.accounts(since: access.history_start).each do |simplefin_account|
        access.update_account(simplefin_account).import(simplefin_account.transactions, sync: self)
      end
      finish
    rescue Simplefin::PaymentRequired
      finish("lapsed")
    rescue Simplefin::AccessRevoked, ActiveRecord::Encryption::Errors::Decryption
      access.revoke
      finish("revoked")
    rescue Simplefin::Unavailable
      finish("unavailable")
    end

    def finish(failure = nil)
      update!(finished_at: Time.current, failure:)
    end
end
