class Transactions::ExclusionsController < ApplicationController
  def update
    transaction = Current.user.transactions.find(params.expect(:transaction_id))
    transaction.update!(params.expect(transaction: [ :excluded ]))
    redirect_back_or_to root_path, status: :see_other
  end
end
