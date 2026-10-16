module ImportsHelper
  FILE_TYPES = ".xlsx,.csv,.tsv,.txt,.xls,.xlsm,.numbers,.ods"

  COLUMN_KINDS = {
    "Skip" => "skip",
    "Date" => "date",
    "Name" => "name",
    "Amount" => "amount",
    "Spent or income" => "spent_or_income",
    "Category" => "category",
    "Transfer" => "transfer",
    "Excluded from totals" => "excluded",
    "Note" => "note"
  }

  POSITIVE_AMOUNTS = { "spent" => "Spent", "income" => "Income" }

  UNREADABLE_SHOWN = 20

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
      "Skipped the #{listed(sheet.skipped_tabs)} tabs, which have different columns."
    end
  end

  def more_rows(sheet)
    sheet.rows.size - sheet.preview.size
  end

  def sheet_header_classes(kind)
    "text-right" if kind == "amount"
  end

  def sheet_cell_classes(kind)
    [ sheet_header_classes(kind), ("font-mono" if kind.in?(%w[ date amount ])), ("text-tertiary" if kind == "skip") ]
  end

  def categories_lead(matched, unmatched)
    if matched.none?
      "Choose what each category becomes."
    elsif unmatched.one?
      "#{pluralize matched.size, "category"} matched yours. Choose what the other one becomes."
    else
      "#{pluralize matched.size, "category"} matched yours. Choose what the other #{unmatched.size} become."
    end
  end

  def matched_summary(matched, unmatched)
    if unmatched.none?
      "Every category matched yours."
    elsif matched.size > 3
      "#{matched.size} matched, like #{listed(matched.first(3).map(&:word))}"
    else
      "#{listed(matched.map(&:word))} matched"
    end
  end

  def category_choices(category_word, category_names)
    choices = category_names.map { |name| [ name, name ] } + [ [ "No category", "" ] ]

    if category_word.match
      choices
    else
      [ [ "New category", category_word.word ] ] + choices
    end
  end

  def tally_counts(tally)
    counts = { "Spent" => tally.spent, "Income" => tally.income }

    if tally.transfers.positive?
      counts["Transfers"] = tally.transfers
    end

    counts.merge("Excluded" => tally.excluded)
  end

  def tally_grid_classes(tally)
    if tally.already_here.zero? && tally.transfers.positive?
      "grid-cols-3 @lg:grid-cols-5"
    else
      "grid-cols-4"
    end
  end

  def tally_note(tally)
    if tally.already_here.positive?
      "Rows you added before are skipped."
    elsif tally.income.positive?
      "Money in with no category counts as income."
    end
  end

  def unreadable_place(row)
    if row.tab
      "#{row.tab}, row #{row.number}"
    else
      "Row #{row.number}"
    end
  end

  def import_footer_note(tally)
    if tally.adding.positive?
      "You can undo the whole import later."
    elsif tally.already_here.positive?
      "Every row in this file is already here."
    else
      "No row can be read. Go back and check the columns."
    end
  end

  private
    def listed(words)
      words.to_sentence(last_word_connector: " and ")
    end
end
