class BankAccounts::HistoriesController < ApplicationController
  unavailable_in_demo

  def create
    bank_account = Current.user.bank_accounts.synced.joins(:simplefin_access).merge(Simplefin::Access.active).find(params.expect(:bank_account_id))
    bank_account.sync_recent_history

    redirect_to settings_path, status: :see_other
  end
end
