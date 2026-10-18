class Transactions::CategorizationsController < ApplicationController
  def update
    transaction = Current.user.transactions.find(params.expect(:transaction_id))
    choice = categorization_params
    transaction.categorize(Transaction::Categorization.from(category: choice[:category], transfer: choice[:transfer], categories: Current.user.categories, money_in: transaction.money_in?))
    redirect_back_or_to root_path, flash: { categorized_id: transaction.id }, status: :see_other
  end

  private
    def categorization_params
      params.expect(categorization: [ :category, :transfer ])
    end
end
