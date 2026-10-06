class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :category, optional: true

  broadcasts_refreshes_to ->(transaction) { [ transaction.user, :transactions ] }

  scope :kept, -> { where(discarded_at: nil) }
  scope :discarded, -> { where.not(discarded_at: nil) }
  scope :latest, -> { order(occurred_on: :desc, id: :desc) }
  scope :occurred_in, ->(dates) { where(occurred_on: dates) }
  scope :spending, -> { where(amount_in_cents: ...0) }

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

  def discard
    update!(discarded_at: Time.current)
  end

  def restore
    update!(discarded_at: nil)
  end
end
