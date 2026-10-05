class WelcomeController < ApplicationController
  def index
    transactions = Current.user.transactions
    @voucher = Voucher.new(flash[:shorthand], user: Current.user, today: Date.current)
    @added = transactions.find_by(id: flash[:added_id])
    @recent = transactions.latest.includes(:category).limit(5)
    @month_count = transactions.occurred_in(Date.current.all_month).count
    @category_names = Current.user.categories.alphabetically.pluck(:name)
  end
end
