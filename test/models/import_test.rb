require "test_helper"
require "turbo/broadcastable/test_helper"

class ImportTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper

  setup do
    @user = users(:one)
  end

  test "an upload reads the file once and keeps its rows, columns, and name" do
    import = Import.find(@user.imports.create!(file: import_file("personal.csv")).id)

    assert_equal [ "personal.csv", %w[ date name category amount excluded note ], 11 ], [ import.filename, import.columns.kinds, import.rows.size ]
    assert_equal [ [ 12, "can't read the amount “abc”" ] ], import.unreadable_rows.map { |row| [ row.number, row.reason ] }
    assert import.draft?
  end

  test "a file it can't use, or no file, leaves a message on file" do
    assert_equal [ "Choose an Excel (.xlsx) or CSV file." ], @user.imports.create(file: upload("receipt.pdf", "%PDF")).errors[:file]
    assert_equal [ "Choose a file." ], @user.imports.create(file: "").errors[:file]
    assert_equal 0, Import.count
  end

  test "the tally counts what Import would add" do
    import = @user.imports.create!(file: import_file("personal.csv"))

    assert_equal Import::Tally.new(spent: 10, income: 0, excluded: 1, unreadable: 1, already_here: 0), import.tally
    assert_equal 11, import.tally.adding
  end

  test "category words list each word on the rows being added, matching the user's own categories" do
    import = @user.imports.create!(file: import_file("personal.csv"))

    assert_equal [ [ "Coffee", 4, "Coffee", false ], [ "Groceries", 3, "Groceries", false ], [ "food", 1, "Food", true ],
                   [ "Fun", 1, "Fun", false ], [ "Housing", 1, "Housing", false ], [ "Travel", 1, "Travel", false ] ],
      import.category_words.map { |category_word| [ category_word.word, category_word.count, category_word.name, category_word.matched? ] }
    assert_equal categories(:food), import.category_words.third.match
  end

  test "a word only on money coming in starts as no category, so it counts as income" do
    import = @user.imports.create!(file: upload("pay.csv", "Date,Name,Category,Amount\n2024-10-01,Coffee,Coffee,-5.50\n2024-10-02,Pay,Salary,2000\n"))

    assert_equal [ [ "Coffee", "Coffee" ], [ "Salary", "" ] ], import.category_words.map { |category_word| [ category_word.word, category_word.name ] }
    assert_equal [ 1, 1 ], [ import.tally.spent, import.tally.income ]
  end

  test "category choices are kept and change the tally: a refund with no category counts as income" do
    import = @user.imports.create!(file: import_file("personal.csv"))

    import.choose_categories([ { word: "Coffee", name: " " }, { word: "Fun", name: " Going  out " } ])
    import = Import.find(import.id)

    assert_equal [ "", "Going out" ], [ import.category_words.first.name, import.category_words.find { |category_word| category_word.word == "Fun" }.name ]
    assert_equal [ 9, 1 ], [ import.tally.spent, import.tally.income ]
  end

  test "Import adds the rows, creating the categories it needs and using the user's own" do
    import = @user.imports.create!(file: import_file("personal.csv"))

    travel_to Time.utc(2026, 10, 15, 12) do
      import.complete
    end

    assert_equal [ Time.utc(2026, 10, 15, 12), nil ], [ import.reload.completed_at, import.sheet ]
    assert_equal [
      [ "2024-10-01", "Blue Bottle", -550, "Coffee", false, nil ],
      [ "2024-10-01", "Blue Bottle", -550, "Coffee", false, nil ],
      [ "2024-10-01", "Blue Bottle", -550, "Coffee", false, nil ],
      [ "2024-10-02", "Whole Foods", -123_456, "Groceries", false, "big shop" ],
      [ "2024-10-03", "Flight to Tokyo", -82_000, "Travel", true, "work trip" ],
      [ "2024-10-04", "Trader Joe's", -4_210, "Groceries", false, nil ],
      [ "2024-10-05", "Blue Bottle", 550, "Coffee", false, "refund" ],
      [ "2024-10-06", "Rent", -200_000, "Housing", false, nil ],
      [ "2024-10-07", "Groceries", -1_800, "Groceries", false, nil ],
      [ "2024-10-09", "Bookshop", -2_400, "Fun", false, nil ],
      [ "2024-10-10", "Sushi", -3_640, "Food", false, nil ]
    ], @user.transactions.where(import:).order(:occurred_on, :id).map { |transaction|
      [ transaction.occurred_on.iso8601, transaction.name, transaction.amount_in_cents, transaction.category&.name, transaction.excluded?, transaction.note ]
    }
    assert_equal [ "Coffee", "Fun", "Groceries", "Housing", "Travel" ], import.created_categories.order(:name).pluck(:name)
    assert_equal [ 10, 336_606 ], [ import.transactions.spending.count, import.transactions.spent ]
  end

  test "Import tells the user's open pages to refresh once" do
    import = @user.imports.create!(file: import_file("personal.csv"))

    perform_enqueued_jobs do
      assert_turbo_stream_broadcasts [ @user, :transactions ], count: 1 do
        import.complete
      end
    end
  end

  test "pressing Import twice, even from two requests at once, adds the rows once" do
    import = @user.imports.create!(file: import_file("personal.csv"))
    first, second = Import.find(import.id), Import.find(import.id)

    first.complete
    second.complete
    import.complete

    assert_equal [ 11, true ], [ import.transactions.count, Import.exists?(import.id) ]
    assert import.reload.completed?
  end

  test "importing the same file again adds nothing and leaves no import behind" do
    @user.imports.create!(file: import_file("personal.csv")).complete
    again = @user.imports.create!(file: import_file("personal.csv"))

    assert_equal [ 0, 11 ], [ again.tally.adding, again.tally.already_here ]
    assert_no_difference -> { Transaction.count } do
      again.complete
    end
    assert_not Import.exists?(again.id)
    assert_equal 1, @user.imports.count
  end

  test "a newer copy of the file adds only its new rows" do
    @user.imports.create!(file: import_file("personal.csv")).complete
    newer = @user.imports.create!(file: upload("personal.csv", file_fixture("imports/personal.csv").read + "2024-10-11,Blue Bottle,Coffee,5.50,,\n2024-10-11,Blue Bottle,Coffee,5.50,,\n"))

    assert_equal [ 2, 11 ], [ newer.tally.adding, newer.tally.already_here ]
    newer.complete
    assert_equal [ [ "2024-10-11", -550 ], [ "2024-10-11", -550 ] ], newer.transactions.map { |transaction| [ transaction.occurred_on.iso8601, transaction.amount_in_cents ] }
  end

  test "a row the user deleted stays deleted when the file is imported again" do
    import = @user.imports.create!(file: import_file("personal.csv"))
    import.complete
    import.transactions.find_by!(name: "Rent").discard

    again = @user.imports.create!(file: import_file("personal.csv"))

    assert_equal [ 0, 11 ], [ again.tally.adding, again.tally.already_here ]
    assert_no_difference -> { Transaction.count } do
      again.complete
    end
  end

  test "an import whose columns aren't chosen yet doesn't add anything" do
    import = @user.imports.create!(file: upload("names.csv", "Name,Amount\nCoffee,5.50\n"))

    import.complete

    assert_equal [ true, [ "Choose a Date column." ] ], [ import.reload.draft?, import.tap(&:valid?).errors[:columns] ]
    assert_equal 0, import.transactions.count
  end

  test "an xlsx workbook imports its yearly tabs" do
    import = @user.imports.create!(file: import_file("history.xlsx"))
    import.complete

    assert_equal [ [ "2023-12-24", "Blue Bottle", -550, "Coffee", false ], [ "2023-12-27", "Whole Foods", -123_456, "Groceries", false ],
                   [ "2023-12-30", "Flight home", -41_200, "Travel", true ], [ "2024-01-02", "Blue Bottle", -550, "Coffee", false ],
                   [ "2024-01-03", "Bookshop", -2_400, "Fun", false ], [ "2024-01-05", "Late dinner", -3_640, "Eating out", false ] ],
      import.transactions.order(:occurred_on).map { |transaction| [ transaction.occurred_on.iso8601, transaction.name, transaction.amount_in_cents, transaction.category.name, transaction.excluded? ] }
  end
end
