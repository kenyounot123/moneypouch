class Transactions::RulesController < ApplicationController
  def create
    transaction = Current.user.transactions.find(params.expect(:transaction_id))
    transaction.make_rule
    redirect_back_or_to root_path, status: :see_other
  end
end
