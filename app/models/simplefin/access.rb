class Simplefin::Access < ApplicationRecord
  HISTORIES = { "today" => 0, "90_days" => 90 }.freeze
  LONGEST_HISTORY = 89
  SYNCS_PER_DAY = 20
  SYNC_EVERY = 23.hours

  belongs_to :user
  has_many :bank_accounts, foreign_key: :simplefin_access_id, inverse_of: :simplefin_access, dependent: :destroy
  has_many :syncs, dependent: :destroy

  encrypts :access_url

  enum :status, %w[ pending active revoked disconnected ].index_by(&:itself)

  delegate :time_zone, to: :user

  scope :due, -> { active.where.not(id: joins(:syncs).merge(Simplefin::Sync.recent(SYNC_EVERY))) }

  def self.sync_due
    Simplefin::Sync.abandon_stale
    due.find_each(&:sync_later)
  end

  def connect(setup_token)
    update!(access_url: Simplefin::Client.claim(setup_token), status: :pending)
    list_accounts
  end

  def activate(account_ids:, history:)
    starts_on = Date.current - HISTORIES.fetch(history)

    transaction do
      update!(status: :active)
      bank_accounts.where(id: Array(account_ids)).each { |bank_account| bank_account.start_syncing(from: starts_on) }
      bank_accounts.where.not(id: Array(account_ids)).each(&:skip)
    end

    sync_later
  end

  def sync_later
    syncs.abandon_stale
    syncs.create!.tap(&:run_later)
  rescue ActiveRecord::RecordNotUnique
    syncs.running.take
  end

  def update_account(simplefin_account)
    bank_accounts.refresh(simplefin_account, user:)
  end

  def revoke
    update!(status: :revoked, access_url: nil)
  end

  def disconnect
    transaction do
      syncs.running.each(&:abandon)
      update!(access_url: nil, status: :disconnected)
    end
  end

  def client
    Simplefin::Client.new(access_url)
  end

  def history_start
    earliest = bank_accounts.synced.minimum(:starts_on) || Date.current
    [ earliest, Date.current - LONGEST_HISTORY ].max.beginning_of_day
  end

  def lapsed?
    syncs.answered.last&.lapsed?
  end

  def syncing?
    syncs.running.exists?
  end

  def syncable?
    syncs.recent(1.day).count < SYNCS_PER_DAY
  end

  def last_synced_at
    syncs.succeeded.maximum(:finished_at)
  end

  def visible_accounts
    if revoked?
      bank_accounts.synced.order(:id)
    else
      bank_accounts.synced.order(:id) + bank_accounts.pending.order(:id)
    end
  end

  private
    def list_accounts
      client.accounts(balances_only: true).each { |simplefin_account| update_account(simplefin_account) }
    rescue Simplefin::Unavailable, Simplefin::PaymentRequired => error
      Rails.logger.warn "SimpleFIN access #{id} could not list accounts: #{error.class}"
    end
end
