class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :category, optional: true
  belongs_to :import, optional: true
  has_one :bank_transaction

  delegate :name, to: :bank_transaction, prefix: true

  MATCH_WINDOW = -5..1

  normalizes :note, with: ->(note) { note.strip.presence }

  broadcasts_refreshes_to ->(transaction) { [ transaction.user, :transactions ] }

  scope :kept, -> { where(discarded_at: nil) }
  scope :latest, -> { order(occurred_on: :desc, id: :desc) }
  scope :occurred_in, ->(dates) { where(occurred_on: dates) }
  scope :counted, -> { where(transfer: false, excluded: false) }
  scope :spending, -> { counted.and(where(amount_in_cents: ...0).or(where.not(category_id: nil))) }
  scope :incoming, -> { counted.where(category_id: nil, amount_in_cents: 0..) }
  scope :listed, -> { latest.includes(:category, :bank_transaction) }
  scope :matchable, -> { where.missing(:bank_transaction) }
  scope :typed_in, -> { where.not(id: BankTransaction.select(:transaction_id)) }
  scope :added_by_bank, -> { where(id: BankTransaction.unmatched.select(:transaction_id)) }
  scope :uncategorized, -> { where(category_id: nil, transfer: false) }
  scope :needing_category, -> { kept.added_by_bank.uncategorized }
  scope :categorized, -> { where.not(category_id: nil) }
  scope :transfers, -> { where(transfer: true) }
  scope :in_category, ->(category) { where(category:) }
  scope :from_bank_account, ->(bank_account) { merge(bank_account.transactions) }

  def self.spending?(amount_in_cents, categorized:)
    amount_in_cents.negative? || categorized
  end

  def self.broadcasting_once_for(user)
    suppressing_turbo_broadcasts { yield }
    Turbo::StreamsChannel.broadcast_refresh_to(user, :transactions)
  end

  def self.matching(query)
    if query.present?
      pattern = "%#{sanitize_sql_like(query.downcase(:ascii))}%"
      where("lower(transactions.name) LIKE :pattern ESCAPE '\\' OR lower(transactions.note) LIKE :pattern ESCAPE '\\'", pattern:)
    else
      all
    end
  end

  def self.spent
    -spending.sum(:amount_in_cents)
  end

  def self.net
    counted.sum(:amount_in_cents)
  end

  def self.income
    incoming.sum(:amount_in_cents)
  end

  def self.match_for(amount_in_cents, currency, date)
    matchable
      .where(amount_in_cents:, currency:, occurred_on: (date + MATCH_WINDOW.begin)..(date + MATCH_WINDOW.end))
      .min_by { |transaction| [ (transaction.occurred_on - date).abs, transaction.id ] }
  end

  def self.add_from_bank(simplefin_transaction, currency:, categorization:)
    create!(
      name: simplefin_transaction.name.to_s,
      amount_in_cents: simplefin_transaction.amount_in_cents,
      currency:,
      occurred_on: simplefin_transaction.occurred_on,
      category: categorization.category,
      transfer: categorization.transfer?
    )
  end

  def self.import(rows, import:, categories:)
    rows.each_slice(500).sum do |slice|
      attributes = slice.map do |row|
        {
          import_id: import.id,
          idempotency_key: row.key,
          name: row.name,
          occurred_on: row.occurred_on,
          amount_in_cents: row.amount_in_cents,
          category_id: categories[row.category_word]&.id,
          excluded: row.excluded?,
          note: normalize_value_for(:note, row.note)
        }
      end

      insert_all(attributes, returning: :id).length
    end
  end

  def self.taken_keys(keys, user:)
    keys.each_slice(1_000).flat_map { |slice| where(user:, idempotency_key: slice).pluck(:idempotency_key) }.to_set
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

  def bank_account_name
    bank_transaction&.bank_account_name
  end

  def counted?
    !transfer? && !excluded?
  end

  def from_bank?
    bank_transaction.present?
  end

  def added_by_bank?
    from_bank? && bank_transaction.unmatched?
  end

  def needs_category?
    added_by_bank? && category_id.nil? && !transfer?
  end

  def categorization
    Categorization.new(category:, transfer:)
  end

  def categorize(categorization)
    update!(category: categorization.category, transfer: categorization.transfer?)
  end

  def offers_rule?
    added_by_bank? && !categorization.none? && !user.remembers?(bank_transaction_name, categorization)
  end

  def make_rule
    if added_by_bank? && !categorization.none?
      user.remember(bank_transaction_name, categorization)
    end
  end

  def waiting_namesake_count
    user.transactions_named(bank_transaction_name.key).needing_category.count
  end

  def discard
    update!(discarded_at: Time.current)
  end

  def restore
    update!(discarded_at: nil)
  end
end
