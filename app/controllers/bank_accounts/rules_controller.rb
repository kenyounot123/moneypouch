class BankAccounts::RulesController < ApplicationController
  def destroy
    bank_account = Current.user.bank_accounts.find(params.expect(:bank_account_id))
    bank_account.rules.find(params.expect(:id)).destroy
    redirect_back_or_to simplefin_review_path, status: :see_other
  end
end
