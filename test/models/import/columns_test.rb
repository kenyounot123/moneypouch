require "test_helper"

class Import::ColumnsTest < ActiveSupport::TestCase
  test "guesses a personal sheet from its header words, with positive amounts as spending" do
    columns = Import::Columns.guess(sheet("personal.csv"))

    assert_equal [ %w[ date name category amount excluded note ], "spent" ], [ columns.kinds, columns.positive_amounts ]
  end

  test "guesses a bank export with signed amounts and leaves its balance column out" do
    columns = Import::Columns.guess(sheet("bank.csv"))

    assert_equal [ %w[ date name amount skip ], "income" ], [ columns.kinds, columns.positive_amounts ]
  end

  test "guesses columns whose headers it doesn't know from what their cells hold" do
    columns = Import::Columns.guess(sheet("european.csv"))

    assert_equal [ %w[ date name amount category ], "income" ], [ columns.kinds, columns.positive_amounts ]
  end

  test "guesses a day-first sheet and a workbook of yearly tabs" do
    assert_equal [ %w[ date name amount ], "spent" ], Import::Columns.guess(sheet("day_first.csv")).then { |columns| [ columns.kinds, columns.positive_amounts ] }
    assert_equal [ %w[ date name category amount excluded ], "spent" ], Import::Columns.guess(sheet("history.xlsx")).then { |columns| [ columns.kinds, columns.positive_amounts ] }
  end

  test "a column of spent and income words is spent or income, and a bank's Type column of other words is only a category" do
    typed = upload("typed.csv", "Date,What,Amount,Type\n2024-10-01,Coffee,5.50,Expense\n2024-10-02,Pay,2000,Income\n")
    bank = upload("chase.csv", "Posting Date,Description,Amount,Type\n10/01/2024,Coffee,-5.50,DEBIT_CARD\n10/02/2024,Payroll,2000,ACH_CREDIT\n")

    assert_equal %w[ date name amount spent_or_income ], Import::Columns.guess(Import::Sheet.read(typed)).kinds
    assert_equal %w[ date name amount category ], Import::Columns.guess(Import::Sheet.read(bank)).kinds
  end

  test "reads a personal sheet: spending turns negative, a negative amount is a refund that keeps its category" do
    rows = Import::Columns.guess(sheet("personal.csv")).read(sheet("personal.csv"))

    assert_equal [
      [ 2, "2024-10-01", "Blue Bottle", -550, "Coffee", false, nil ],
      [ 3, "2024-10-01", "Blue Bottle", -550, "Coffee", false, nil ],
      [ 4, "2024-10-01", "Blue Bottle", -550, "Coffee", false, nil ],
      [ 5, "2024-10-02", "Whole Foods", -123_456, "Groceries", false, "big shop" ],
      [ 6, "2024-10-03", "Flight to Tokyo", -82_000, "Travel", true, "work trip" ],
      [ 8, "2024-10-04", "Trader Joe's", -4_210, "Groceries", false, nil ],
      [ 9, "2024-10-05", "Blue Bottle", 550, "Coffee", false, "refund" ],
      [ 10, "2024-10-06", "Rent", -200_000, "Housing", false, nil ],
      [ 11, "2024-10-07", "Groceries", -1_800, "Groceries", false, nil ],
      [ 13, "2024-10-09", "Bookshop", -2_400, "Fun", false, nil ],
      [ 14, "2024-10-10", "Sushi", -3_640, "food", false, nil ]
    ], rows.grep(Import::Row).map { |row| [ row.number, row.occurred_on.iso8601, row.name, row.amount_in_cents, row.category_word, row.excluded?, row.note ] }
    assert_equal [ [ nil, 12, "can't read the amount “abc”" ] ], rows.grep(Import::UnreadableRow).map { |row| [ row.tab, row.number, row.reason ] }
  end

  test "identical rows on one day each get their own key, and a newer copy of the file gives them the same keys" do
    older = upload("older.csv", "Date,Name,Amount\n2024-10-01,Blue Bottle,5.50\n2024-10-01,blue  bottle,5.50\n")
    newer = upload("newer.csv", "Date,Name,Amount\n2024-10-01,Blue Bottle,5.50\n2024-10-01,Blue Bottle,5.50\n2024-10-02,Blue Bottle,5.50\n")
    columns = Import::Columns.new(kinds: %w[ date name amount ], positive_amounts: "spent")

    older_keys = columns.read(Import::Sheet.read(older)).map(&:key)
    newer_keys = columns.read(Import::Sheet.read(newer)).map(&:key)

    assert_equal 2, older_keys.uniq.size
    assert_equal older_keys, newer_keys.first(2)
    assert_not_includes older_keys, newer_keys.last
    assert_match(/\Aimport:\h{64}\z/, newer_keys.last)
  end

  test "flipping which way positive amounts go changes the signs but not the keys" do
    file = sheet("bank.csv")
    as_written = Import::Columns.new(kinds: %w[ date name amount skip ], positive_amounts: "income").read(file)
    flipped = Import::Columns.new(kinds: %w[ date name amount skip ], positive_amounts: "spent").read(file)

    assert_equal [ -450, 200_000 ], as_written.first(2).map(&:amount_in_cents)
    assert_equal [ 450, -200_000 ], flipped.first(2).map(&:amount_in_cents)
    assert_equal as_written.map(&:key), flipped.map(&:key)
  end

  test "a spent or income column signs each row, and income drops its category" do
    file = Import::Sheet.read(upload("typed.csv", <<~CSV))
      Date,What,Category,Amount,Type
      2024-10-01,Coffee,Food,5.50,Expense
      2024-10-02,Coffee refund,Food,-5.50,expense
      2024-10-03,Pay,Salary,2000,Income
      2024-10-04,To savings,,100,Transfer
      2024-10-05,Mystery,,7,
    CSV
    rows = Import::Columns.new(kinds: %w[ date name category amount spent_or_income ], positive_amounts: "spent").read(file)

    assert_equal [ [ "Coffee", -550, "Food" ], [ "Coffee refund", 550, "Food" ], [ "Pay", 200_000, nil ] ],
      rows.grep(Import::Row).map { |row| [ row.name, row.amount_in_cents, row.category_word ] }
    assert_equal [ "“Transfer” isn't spent or income", "there's no spent or income" ], rows.grep(Import::UnreadableRow).map(&:reason)
  end

  test "a row without a name takes its category's, and without either it can't be read" do
    file = Import::Sheet.read(upload("names.csv", "Date,Name,Category,Amount\n2024-10-01,,Coffee,5.50\n2024-10-02,,,5.50\n"))
    rows = Import::Columns.new(kinds: %w[ date name category amount ], positive_amounts: "spent").read(file)

    assert_equal [ "Coffee", "there's no name" ], [ rows.first.name, rows.last.reason ]
  end

  test "each row it can't read says why, and rows with no date are left out" do
    file = Import::Sheet.read(upload("messy.csv", <<~CSV))
      Date,Name,Amount
      2024-10-01,Coffee,5.50
      2024-13-45,Tea,3.00
      2024-10-02,Lunch,
      2024-10-03,Dinner,twelve
      2024-10-04,Free sample,0
      Total,,8.50
      ,Subtotal,8.50
      Date,Name,Amount
    CSV
    rows = Import::Columns.new(kinds: %w[ date name amount ], positive_amounts: "spent").read(file)

    assert_equal [ "Coffee" ], rows.grep(Import::Row).map(&:name)
    assert_equal [ [ 3, "can't read the date “2024-13-45”" ], [ 4, "there's no amount" ], [ 5, "can't read the amount “twelve”" ], [ 6, "the amount is 0" ] ],
      rows.grep(Import::UnreadableRow).map { |row| [ row.number, row.reason ] }
  end

  test "an Excluded cell is yes unless it reads as no" do
    file = Import::Sheet.read(upload("excluded.csv", "Date,Name,Amount,Excluded\n" + %w[ yes x TRUE 1 no N false 0 - ].map { |value| "2024-10-01,Coffee,5.50,#{value}\n" }.join + "2024-10-01,Coffee,5.50,\n"))
    rows = Import::Columns.new(kinds: %w[ date name amount excluded ], positive_amounts: "spent").read(file)

    assert_equal [ true, true, true, true, false, false, false, false, false, false ], rows.map(&:excluded?)
  end

  test "typed xlsx cells read as their dates, amounts, and true or false" do
    file = sheet("history.xlsx")
    rows = Import::Columns.guess(file).read(file)

    assert_equal [ [ "2023", 6, Date.new(2023, 12, 30), -41_200, true ], [ "2024", 4, Date.new(2024, 1, 5), -3_640, false ] ],
      rows.values_at(2, 5).map { |row| [ row.tab, row.number, row.occurred_on, row.amount_in_cents, row.excluded? ] }
    assert_equal 6, rows.size
  end

  test "the Columns step's messages say what's missing or chosen twice" do
    assert_equal [], Import::Columns.new(kinds: %w[ date name amount ], positive_amounts: "spent").errors
    assert_equal [ "Choose a Date column.", "Choose an Amount column.", "Only one column can be Name." ],
      Import::Columns.new(kinds: %w[ name name skip ], positive_amounts: "spent").errors
    assert_equal [ "Only one column can be Spent or income." ],
      Import::Columns.new(kinds: %w[ date amount spent_or_income spent_or_income ], positive_amounts: "spent").errors
  end

  test "columns with a missing kind read no rows" do
    assert_equal [], Import::Columns.new(kinds: %w[ skip name amount skip excluded note ], positive_amounts: "spent").read(sheet("personal.csv"))
  end

  test "the Columns step's choice is fitted to the sheet's width and unknown kinds become skip" do
    columns = Import::Columns.from({ columns: [ "date", "name", "bogus", "amount", "note", "extra" ], positive_amounts: "income" }, sheet: sheet("bank.csv"))

    assert_equal [ %w[ date name skip amount ], "income" ], [ columns.kinds, columns.positive_amounts ]
    assert_equal [ "amount", "skip" ], [ columns.kind_at(3), columns.kind_at(9) ]
    assert_equal "spent", Import::Columns.from({ positive_amounts: "sideways" }, sheet: sheet("bank.csv")).positive_amounts
  end

  test "the positive amounts choice matters only without a spent or income column" do
    assert Import::Columns.new(kinds: %w[ date name amount ], positive_amounts: "spent").needs_positive_amounts?
    assert_not Import::Columns.new(kinds: %w[ date name amount spent_or_income ], positive_amounts: "spent").needs_positive_amounts?
  end

  test "the stored form brings the same columns back" do
    columns = Import::Columns.new(kinds: %w[ date name amount ], positive_amounts: "income")

    assert_equal columns, Import::Columns.load(Import::Columns.dump(columns))
    assert_nil Import::Columns.load(nil)
  end

  private
    def sheet(name)
      Import::Sheet.read(import_file(name))
    end
end
