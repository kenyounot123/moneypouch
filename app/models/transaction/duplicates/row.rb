class Transaction::Duplicates::Row < Data.define(:id, :currency, :amount_in_cents, :occurred_on, :bank_transaction_id, :name_key)
  def initialize(bank_transaction_id: nil, name_key: nil, **)
    super
  end

  def money
    [ currency, amount_in_cents ]
  end

  def money_with(other)
    [ currency, amount_in_cents + other.amount_in_cents ]
  end

  def times_into(other)
    if same_direction?(other) && (other.amount_in_cents % amount_in_cents).zero?
      other.amount_in_cents / amount_in_cents
    else
      0
    end
  end

  def same_direction?(other)
    currency == other.currency && (amount_in_cents <=> 0) == (other.amount_in_cents <=> 0)
  end

  def before?(other)
    ([ occurred_on, id ] <=> [ other.occurred_on, other.id ]).negative?
  end

  def days_from(other)
    (occurred_on.jd - other.occurred_on.jd).abs
  end
end
