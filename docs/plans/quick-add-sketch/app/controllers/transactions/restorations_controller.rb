# P9. POST /transactions/:transaction_id/restoration (undo of a discard)
# Reaches only the discarded side, so another user's id, or a row already
# restored, is a 404: a repeated restore can never write twice.
class Transactions::RestorationsController < ApplicationController
  def create
    transaction = Current.user.discarded_transactions.find(params.expect(:transaction_id))
    transaction.restore
    raise NotImplementedError # render "transactions/change" with no inverse
  end
end
