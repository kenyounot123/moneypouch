class Transactions::CategorizationsController < ApplicationController
  def update
    transaction = Current.user.transactions.find(params.expect(:transaction_id))
    transaction.categorize(Transaction::Categorization.from(params, categories: Current.user.categories, money_in: transaction.money_in?))
    redirect_back_or_to root_path, flash: { categorized_id: transaction.id }, status: :see_other
  end
end
