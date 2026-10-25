# The transactions behind the Transactions page or a category's page, narrowed by a search query, and their totals. A query that narrows spans every month unless it names its dates.
class Transaction::Listing
  Day = Data.define(:on, :rows, :net, :spending, :income)

  attr_reader :period, :query, :sort

  def initialize(transactions, period:, query:, before:, sort: Transaction::Sort.default, number: 1)
    @transactions = transactions
    @period = period
    @query = query
    @before = before
    @sort = sort
    @number = number
  end

  def page
    @page ||= if sort.grouped_by_day?
      Transaction::Page.new(shown, counts: days.to_h { |day| [ day.on, day.rows ] }, before: @before)
    else
      Transaction::FlatPage.new(shown, count:, number: @number)
    end
  end

  def transactions
    @transactions_on_page ||= sort.order(page.transactions.listed).includes(bank_transaction: [ :bank_account, { transfer_partner: :bank_account } ])
  end

  def count
    days.sum(&:rows)
  end

  def needing_category_count
    narrowed(except: Transaction::Query::NEEDS).needing_category.count
  end

  def spent
    -days.sum(&:spending)
  end

  def net
    days.sum(&:net)
  end

  def income
    days.sum(&:income)
  end

  def day_totals
    @day_totals ||= Hash.new(0).merge(days.to_h { |day| [ day.on, day.net ] })
  end

  private
    def days
      @days ||= shown.group(:occurred_on).order(occurred_on: sort.direction).pluck(:occurred_on, *totals).map { |values| Day.new(*values) }
    end

    def totals
      counted = "NOT transactions.transfer AND NOT transactions.excluded"
      spending = "transactions.category_id IN (#{Category.spending.select(:id).to_sql}) OR (transactions.category_id IS NULL AND transactions.amount_in_cents < 0)"
      income = "transactions.category_id IN (#{Category.income.select(:id).to_sql}) OR (transactions.category_id IS NULL AND transactions.amount_in_cents >= 0)"

      [ "COUNT(*)", sum_where(counted), sum_where("#{counted} AND (#{spending})"), sum_where("#{counted} AND (#{income})") ].map { |sql| Arel.sql(sql) }
    end

    def sum_where(condition)
      "SUM(CASE WHEN #{condition} THEN transactions.amount_in_cents ELSE 0 END)"
    end

    def shown
      @shown ||= narrowed
    end

    def narrowed(except: nil)
      query.scope(within_period, except:)
    end

    def within_period
      if query.filtering?
        @transactions
      else
        @transactions.occurred_in(period.range)
      end
    end
end
