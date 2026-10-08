class BankAccountsController < ApplicationController
  def update
    bank_account = Current.user.bank_accounts.pending.find(params.expect(:id))

    case params.expect(bank_account: [ :status ])[:status]
    when "synced" then bank_account.start_syncing
    when "skipped" then bank_account.skip
    else raise ActionController::BadRequest
    end

    redirect_to settings_path, status: :see_other
  end
end
