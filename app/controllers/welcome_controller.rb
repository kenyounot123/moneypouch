class WelcomeController < ApplicationController
  def index
    transactions = Current.user.transactions
    @draft = Transaction::Draft.parse(flash[:line], user: Current.user, today: Date.current)
    @added = transactions.find_by(id: flash[:added_id])
    @recent = transactions.latest.includes(:category).limit(5)
    @month_count = transactions.occurred_in(Date.current.all_month).count
  end
end
