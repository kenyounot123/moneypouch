module Transaction::Exportable
  extend ActiveSupport::Concern

  class_methods do
    def to_csv
      CSV.generate do |csv|
        csv << [ "Date", "Name", "Amount", "Category", "Transfer", "Excluded", "Note", "Bank account" ]

        includes(:category, bank_transaction: :bank_account).latest.each do |transaction|
          csv << transaction.csv_row
        end
      end
    end
  end

  def csv_row
    [ occurred_on.iso8601, name, format("%.2f", amount_in_cents / 100r), category&.name, ("yes" if transfer?), ("yes" if excluded?), note, bank_account_name ]
  end
end
