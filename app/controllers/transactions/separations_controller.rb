class Transactions::SeparationsController < ApplicationController
  def create
    Current.user.keep_both(params.expect(:transaction_id).to_i, params.expect(bank_transaction_ids: []).map(&:to_i))
    redirect_back_or_to simplefin_review_path, status: :see_other
  end
end
