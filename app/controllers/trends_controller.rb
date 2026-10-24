class TrendsController < ApplicationController
  def show
    @trends = Trends.new(Current.user.transactions, today: Date.current)
  end
end
