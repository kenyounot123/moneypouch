class Transactions::ExclusionsController < ApplicationController
  def update
    transaction = Current.user.transactions.find(params.expect(:transaction_id))
    transaction.update!(exclusion_params)
    redirect_back_or_to root_path, status: :see_other
  end

  private
    def exclusion_params
      params.expect(transaction: [ :excluded ])
    end
end
