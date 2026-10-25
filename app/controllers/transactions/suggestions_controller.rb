class Transactions::SuggestionsController < ApplicationController
  MERCHANTS = 500

  def show
    render json: Current.user.transactions.merchants(MERCHANTS)
  end
end
