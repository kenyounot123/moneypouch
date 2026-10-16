module ImportsHelper
  FILE_TYPES = ".xlsx,.csv,.tsv,.txt,.xls,.xlsm,.numbers,.ods"

  COLUMN_KINDS = {
    "Skip" => "skip",
    "Date" => "date",
    "Name" => "name",
    "Amount" => "amount",
    "Spent or income" => "spent_or_income",
    "Category" => "category",
    "Excluded from totals" => "excluded",
    "Note" => "note"
  }

  POSITIVE_AMOUNTS = { "spent" => "Spent", "income" => "Income" }

  def imported_transactions(import)
    pluralize(number_with_delimiter(import.transactions.count), "transaction")
  end

  def latest_import_sentence(import)
    "Imported #{imported_transactions import} from #{import.filename} on #{short_date import.completed_at.to_date}."
  end

  def undo_import_question(import)
    "Remove the #{imported_transactions import} from #{import.filename}?"
  end

  def sheet_extent(sheet)
    rows = pluralize(number_with_delimiter(sheet.rows.size), "row")

    if sheet.tabs.many?
      "#{rows} from #{sheet.tabs.size} tabs"
    else
      rows
    end
  end

  def skipped_tabs_sentence(sheet)
    if sheet.skipped_tabs.one?
      "Skipped the #{sheet.skipped_tabs.first} tab, which has different columns."
    else
      "Skipped the #{sheet.skipped_tabs.to_sentence} tabs, which have different columns."
    end
  end

  def more_rows(sheet)
    sheet.rows.size - sheet.preview.size
  end

  def sheet_cell_classes(kind)
    [ ("font-mono" if kind.in?(%w[ date amount ])), ("text-tertiary" if kind == "skip") ]
  end
end
