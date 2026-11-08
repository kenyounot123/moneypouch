module ImportsHelper
  FILE_TYPES = ".xlsx,.csv,.tsv,.txt,.xls,.xlsm,.numbers,.ods"

  # Titled and ordered here, listed in Import::Columns::KINDS. The helper test checks the two agree.
  COLUMN_KINDS = {
    "skip" => { title: "Skip", hint: "Leave this column out." },
    "date" => { title: "Date", hint: "When it happened." },
    "name" => { title: "Name", hint: "Who you paid or who paid you." },
    "amount" => { title: "Amount", hint: "How much." },
    "spent_or_income" => { title: "Spent or income", hint: "Says if money went out or came in." },
    "category" => { title: "Category", hint: "What it was for, like Groceries." },
    "transfer" => { title: "Transfer", hint: "Marks money moved between your own accounts." },
    "excluded" => { title: "Excluded from totals", hint: "Marks rows to keep out of totals." },
    "note" => { title: "Note", hint: "Anything else you wrote down." }
  }

  FIELD_ORDER = %w[ date amount name spent_or_income category transfer excluded note ]

  POSITIVE_AMOUNTS = { "spent" => "Spent", "income" => "Income" }

  ROWS_SHOWN = 20

  ALREADY_HERE_SOURCES = {
    deleted: "deleted before",
    bank: "from your bank",
    import: "from %{filename}",
    typed: "typed in"
  }

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

  def column_options
    Import::Columns::KINDS.map { |kind| [ kind_title(kind), kind ] }
  end

  def column_fields(columns)
    needed, optional = FIELD_ORDER.partition { |kind| columns.needed?(kind) }

    { "Needed" => needed, "If your file has them" => optional }
  end

  def kind_title(kind)
    COLUMN_KINDS.fetch(kind)[:title]
  end

  def kind_hint(kind)
    COLUMN_KINDS.fetch(kind)[:hint]
  end

  def column_source(sheet, columns, kind)
    index = columns.index_of(kind)

    if index
      sheet.headers[index]
    end
  end

  def sheet_header_classes(kind)
    "text-right" if kind == "amount"
  end

  def sheet_cell_classes(kind)
    [ sheet_header_classes(kind), ("font-amount" if kind.in?(%w[ date amount ])), ("text-tertiary" if kind == "skip") ]
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

    if category_word.matched?
      choices
    else
      [ [ "New category", category_word.word ] ] + choices
    end
  end

  def money_in_choices(category_word, income_names)
    income_names.map { |name| [ name, name ] } + [ [ "Refund to #{category_word.name}", "" ] ]
  end

  def money_in_sentence(category_word)
    count = number_with_delimiter(category_word.money_in_count)
    money_in = tag.span("money in", class: "text-success")

    if category_word.money_in_count == 1
      safe_join([ "#{count} is ", money_in ])
    else
      safe_join([ "#{count} are ", money_in ])
    end
  end

  def tally_line_label(line)
    count = number_with_delimiter(line.count)

    case line.kind
    when :refund, :transfer
      "#{count} #{line.kind.to_s.pluralize(line.count)}"
    else
      "#{count} #{line.kind}"
    end
  end

  def new_rows_lines(tally)
    tally.lines.map { |line| [ tally_line_label(line), money(line.cents) ] }
  end

  def already_here_lines(tally)
    tally.already_here.first(ROWS_SHOWN).map do |row, transaction|
      [ [ row_place(row), short_date(row.occurred_on), row.name, already_here_source(transaction) ].join(" · "), money(row.written_cents) ]
    end
  end

  def unreadable_lines(tally)
    tally.unreadable_rows.first(ROWS_SHOWN).map do |row|
      [ [ row_place(row), row.name, row.reason.upcase_first ].compact.join(" · "), nil ]
    end
  end

  def rows_not_shown(rows)
    [ rows.size - ROWS_SHOWN, 0 ].max
  end

  def already_here_source(transaction)
    source = if transaction.discarded_at
      :deleted
    elsif transaction.from_bank?
      :bank
    elsif transaction.import
      :import
    else
      :typed
    end

    ALREADY_HERE_SOURCES.fetch(source) % { filename: transaction.import&.filename }
  end

  def total_check_sentence(check, filename)
    case check
    when :matches
      "Matches the Total row in #{filename}"
    when Import::StatedTotal
      "The Total row #{check.tab ? "on the #{check.tab} tab" : "in #{filename}"} says #{money(check.cents)}"
    end
  end

  def row_place(row)
    if row.tab
      "#{row.tab}, row #{row.number}"
    else
      "Row #{row.number}"
    end
  end

  def import_footer_note(tally)
    if tally.adding.positive?
      "You can undo the whole import later."
    elsif tally.already_here.any?
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
