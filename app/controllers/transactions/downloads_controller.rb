class Transactions::DownloadsController < ApplicationController
  def show
    send_data Current.user.transactions.to_csv, filename: "moneypouch-#{Date.current.iso8601}.csv", type: :csv
  end
end
