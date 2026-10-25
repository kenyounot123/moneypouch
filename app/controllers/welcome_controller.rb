class WelcomeController < ApplicationController
  def index
    transactions = Current.user.transactions
    @added = transactions.find_by(id: flash[:added_id])
    @recent = transactions.listed.limit(5)
    @categories = Current.user.categories.alphabetically
    @period = Period.new(params[:period], today: Date.current)
    @spending = Spending.new(transactions, @period)
    @chart = Chart.new(params[:chart])
    @summary = Summary.new(transactions, @period) if @chart.summary?
    @focus = Period.new(@period.kind, today: Date.current, on: params[:focus]) if @chart.summary? && params[:focus].present?
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
