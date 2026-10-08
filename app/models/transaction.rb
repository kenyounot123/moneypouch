class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :category, optional: true
  has_one :bank_transaction

  MATCH_WINDOW = -5..1

  broadcasts_refreshes_to ->(transaction) { [ transaction.user, :transactions ] }

  scope :kept, -> { where(discarded_at: nil) }
  scope :discarded, -> { where.not(discarded_at: nil) }
  scope :latest, -> { order(occurred_on: :desc, id: :desc) }
  scope :occurred_in, ->(dates) { where(occurred_on: dates) }
  scope :spending, -> { where(amount_in_cents: ...0) }
  scope :listed, -> { latest.includes(:category, :bank_transaction) }
  scope :matchable, -> { where.missing(:bank_transaction) }

  def self.broadcasting_once_for(user)
    suppressing_turbo_broadcasts { yield }
    Turbo::StreamsChannel.broadcast_refresh_to(user, :transactions)
  end

  def self.match_for(amount_in_cents, currency, date)
    matchable
      .where(amount_in_cents:, currency:, occurred_on: (date + MATCH_WINDOW.begin)..(date + MATCH_WINDOW.end))
      .min_by { |transaction| [ (transaction.occurred_on - date).abs, transaction.id ] }
  end

  def self.import(simplefin_transaction, currency:)
    name = simplefin_transaction.payee || simplefin_transaction.description

    create!(
      name:,
      amount_in_cents: simplefin_transaction.amount_in_cents,
      currency:,
      occurred_on: simplefin_transaction.occurred_on,
      category: last_category_for(name)
    )
  end

  def self.last_category_for(name)
    eager_load(:category)
      .where("lower(transactions.name) = ?", name.downcase(:ascii))
      .order(occurred_on: :desc, id: :desc)
      .first&.category
  end

  def self.name_starting_with(prefix)
    where("lower(transactions.name) LIKE ? ESCAPE '\\'", "#{sanitize_sql_like(prefix.downcase(:ascii))}%")
      .where("length(transactions.name) > ?", prefix.length)
      .group(:name)
      .order(Arel.sql("count(*) DESC, max(transactions.occurred_on) DESC"))
      .pick(:name)
  end

  def added_on
    (created_at || Time.current).in_time_zone.to_date
  end

  def from_bank?
    bank_transaction.present?
  end

  def unsorted?
    from_bank? && !bank_transaction.matched? && category_id.nil?
  end

  def discard
    update!(discarded_at: Time.current)
  end

  def restore
    update!(discarded_at: nil)
  end
end
