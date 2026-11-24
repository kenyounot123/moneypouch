class Transactions::MergesController < ApplicationController
  def create
    Current.user.merge_duplicate(params.expect(:transaction_id).to_i, params.expect(bank_transaction_ids: []).map(&:to_i))
    redirect_back_or_to simplefin_review_path, status: :see_other
  end
end
