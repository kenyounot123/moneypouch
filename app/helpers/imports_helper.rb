module ImportsHelper
  FILE_TYPES = ".xlsx,.csv,.tsv,.txt,.xls,.xlsm,.numbers,.ods"

  def imported_transactions(import)
    pluralize(number_with_delimiter(import.transactions.count), "transaction")
  end

  def latest_import_sentence(import)
    "Imported #{imported_transactions import} from #{import.filename} on #{short_date import.completed_at.to_date}."
  end

  def undo_import_question(import)
    "Remove the #{imported_transactions import} from #{import.filename}?"
  end
end
