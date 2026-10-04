# P6. The Overview. Three page queries (Spending, Recent, sidebar count) plus the
# two Authentication queries = 5, under the budget of 6.
class WelcomeController < ApplicationController
  def index
    transactions = Current.user.transactions
    @spending = Spending.new(transactions, month: Month.current)
    @recent = transactions.latest_stashed.eager_load(:category).limit(5).to_a # loaded once; the view checks .empty? without another query
  end
end
