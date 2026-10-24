# The transactions over a period, one month on the Transactions page or a span on a category's page, narrowed by filters, and their totals.
class Transaction::Listing
  attr_reader :period, :filters

  def initialize(user, period:, filters:, before:)
    @user = user
    @period = period
    @filters = filters
    @before = before
  end

  def page
    @page ||= Transaction::Page.new(shown, before: @before)
  end

  def transactions
    @transactions ||= page.transactions.listed.includes(bank_transaction: [ :bank_account, { transfer_partner: :bank_account } ])
  end

  def count
    @count ||= shown.count
  end

  def needing_category_count
    narrowed.needing_category.count
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
    attr_reader :user

    def shown
      if filters[:needs]
        narrowed.needing_category
      else
        narrowed
      end
    end

    def narrowed
      in_chosen_category(from_chosen_account(user.transactions.occurred_in(period.range).matching(filters[:query])))
    end

    def from_chosen_account(transactions)
      case filters[:account]
      when nil then transactions
      when "typed" then transactions.typed_in
      else transactions.from_bank_account(user.bank_accounts.find(filters[:account]))
      end
    end

    def in_chosen_category(transactions)
      case filters[:category]
      when nil then transactions
      when "none" then transactions.uncategorized
      else transactions.in_category(user.categories.find(filters[:category]))
      end
    end
end
