# How the Transactions page orders its rows, read from the sort and direction in the URL. Every column's ordering lives in COLUMNS, so a header, a link and a query all derive from one table.
class Transaction::Sort < Data.define(:key, :direction)
  Column = Data.define(:default, :joins, :order)

  COLUMNS = {
    "date" => Column.new(default: "desc", joins: nil, order: ->(direction) { "transactions.occurred_on #{direction}" }),
    "name" => Column.new(default: "asc", joins: nil, order: ->(direction) { "lower(transactions.name) #{direction}" }),
    "category" => Column.new(default: "asc", joins: :category,
      order: ->(direction) { "(transactions.transfer OR transactions.category_id IS NULL), lower(categories.name) #{direction}" }),
    "account" => Column.new(default: "asc", joins: { bank_transaction: :bank_account },
      order: ->(direction) { "bank_accounts.id IS NULL, lower(bank_accounts.institution) #{direction}, lower(bank_accounts.name) #{direction}" }),
    "amount" => Column.new(default: "asc", joins: nil, order: ->(direction) { "transactions.amount_in_cents #{direction}" })
  }.freeze

  DIRECTIONS = %w[ asc desc ].freeze
  TIEBREAK = "transactions.occurred_on DESC, transactions.id DESC"

  private_class_method :new

  class << self
    def parse(key, direction)
      column = COLUMNS[key.to_s]

      if column
        new(key.to_s, DIRECTIONS.include?(direction.to_s) ? direction.to_s : column.default)
      else
        default
      end
    end

    def default
      new("date", COLUMNS.fetch("date").default)
    end
  end

  def order(scope)
    scope = scope.left_joins(column.joins) if column.joins
    scope.reorder(Arel.sql("#{column.order.call(direction)}, #{TIEBREAK}"))
  end

  def grouped_by_day?
    key == "date"
  end

  def toggle(other)
    self.class.parse(other, (opposite if other.to_s == key))
  end

  def ascending?
    direction == "asc"
  end

  def default?
    self == self.class.default
  end

  def params
    if default?
      {}
    else
      { sort: key, direction: (direction unless direction == column.default) }.compact
    end
  end

  private
    def column
      COLUMNS.fetch(key)
    end

    def opposite
      ascending? ? "desc" : "asc"
    end
end
