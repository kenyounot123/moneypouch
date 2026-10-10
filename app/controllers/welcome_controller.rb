class WelcomeController < ApplicationController
  def index
    transactions = Current.user.transactions
    @voucher = Voucher.new(flash[:shorthand], user: Current.user, today: Date.current)
    @added = transactions.find_by(id: flash[:added_id])
    @recent = transactions.listed.limit(5)
    @total_count = transactions.count
    @since = transactions.minimum(:occurred_on)
    @category_names = Current.user.categories.alphabetically.pluck(:name)
    @period = Period.new(params[:period], today: Date.current)
    @spending = Spending.new(transactions, @period)
  end
end
