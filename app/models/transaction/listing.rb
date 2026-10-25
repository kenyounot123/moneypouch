# The transactions behind the Transactions page or a category's page, narrowed by a search query, and their totals. A query that narrows spans every month unless it names its dates.
class Transaction::Listing
  attr_reader :period, :query

  def initialize(transactions, period:, query:, before:)
    @transactions = transactions
    @period = period
    @query = query
    @before = before
  end

  def page
    @page ||= Transaction::Page.new(shown, before: @before)
  end

  def transactions
    @transactions_on_page ||= page.transactions.listed.includes(bank_transaction: [ :bank_account, { transfer_partner: :bank_account } ])
  end

  def count
    @count ||= shown.count
  end

  def needing_category_count
    narrowed(except: Transaction::Query::NEEDS).needing_category.count
  end

  def spent
    shown.spent
  end

  def net
    shown.net
  end

  def income
    shown.income
  end

  def day_totals
    @day_totals ||= Hash.new(0).merge(shown.counted.group(:occurred_on).sum(:amount_in_cents))
  end

  private
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
