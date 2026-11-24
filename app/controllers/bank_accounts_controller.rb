class BankAccountsController < ApplicationController
  unavailable_in_demo

  def update
    case params.expect(bank_account: [ :status ])[:status]
    when "synced" then Current.user.bank_accounts.pending.find(params.expect(:id)).sync_recent_history
    when "skipped" then Current.user.bank_accounts.undecided.find(params.expect(:id)).skip
    else raise ActionController::BadRequest
    end

    redirect_to settings_path, status: :see_other
  end
end
