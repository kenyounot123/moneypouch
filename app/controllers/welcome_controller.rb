class WelcomeController < ApplicationController
  def index
    transactions = Current.user.transactions
    @voucher = Voucher.new(flash[:shorthand], user: Current.user, today: Date.current)
    @added = transactions.find_by(id: flash[:added_id])
    @recent = transactions.listed.limit(5)
    @category_names = Current.user.categories.alphabetically.pluck(:name)
    @period = Period.new(params[:period], today: Date.current)
    @spending = Spending.new(transactions, @period)
    @chart = Chart.new(params[:chart])
    @summary = Summary.new(transactions, today: Date.current) if @chart.summary?
    @month = Month.new(params[:month], today: Date.current) if @chart.summary? && params[:month].present?
    @review = Current.user.simplefin_access&.review
    @review_rows = review_rows
    @syncing = Current.user.simplefin_access&.syncing?
  end

  private
    def review_rows
      if @review&.pending?
        @review.transactions_in("needing_category", including: flash[:categorized_id]).first(3)
      else
        []
      end
    end
end
