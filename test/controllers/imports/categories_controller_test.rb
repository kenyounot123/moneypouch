require "test_helper"

class Imports::CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "Categories asks about the words that didn't match and folds the ones that did" do
    import = @user.start_import(import_file("personal.csv"))

    get edit_import_categories_url(import)

    assert_response :success
    assert_select "form p", text: "1 category matched yours. Choose what the other 5 become."
    assert_equal [ "Coffee", "Groceries", "Fun", "Housing", "Travel", "food" ], css_select("form p.text-md").map(&:text)
    assert_select "select[aria-label='What Coffee becomes'][data-action='change->auto-submit#submit'] option[selected][value=Coffee]", text: "New category"
    assert_equal [ "New category", "Food", "Income", "No category" ], css_select("select[aria-label='What Coffee becomes'] option").map(&:text)
    assert_select "button[aria-controls=matched_categories][aria-expanded=false]", text: /food matched\s+Show/
    assert_select "#matched_categories[hidden] select[aria-label='What food becomes'] option[selected]", text: "Food"
    assert_equal [ "Food", "Income", "No category" ], css_select("select[aria-label='What food becomes'] option").map(&:text)
    assert_select "main button", text: "Cancel", count: 0
    assert_select "h1", text: "Categories"
    assert_select "nav[aria-label=Breadcrumb] li", count: 3
    assert_select "nav[aria-label=Breadcrumb] a[href=?]", new_import_path, text: "Import"
    assert_select "nav[aria-label=Breadcrumb] a[href=?]", edit_import_columns_path(import), text: "Columns"
    assert_select "nav[aria-label=Breadcrumb] [aria-current=page]", text: "Categories"
    assert_select "a", text: "Back", count: 0
  end

  test "a word with money in under a spending category asks where its money in goes" do
    import = @user.start_import(import_file("personal.csv"))

    get edit_import_categories_url(import)

    assert_select "p", text: "└ 1 is money in"
    assert_select "p span.text-success", text: "money in"
    assert_select "select[aria-label='What Coffee money in becomes'][data-action='change->auto-submit#submit'] option[selected]", text: "Refund to Coffee"
    assert_equal [ "Income", "Refund to Coffee" ], css_select("select[aria-label='What Coffee money in becomes'] option").map(&:text)
    assert_select "select[aria-label^='What Groceries money in']", count: 0
  end

  test "the preview adds up the file: what's new by kind, what can't be read, and a total that matches the file's own" do
    import = @user.start_import(import_file("personal.csv"))

    get edit_import_categories_url(import)

    assert_equal [ "New", "11 rows", "$4,186.06" ], heading("New")
    assert_equal [ [ "└ 9 spent", "$3,371.56" ], [ "└ 1 refund", "−$5.50" ], [ "└ 1 excluded", "$820.00" ] ], lines("New")
    assert_select "section[aria-label='Already here']", count: 0
    assert_equal [ "Can't read", "1 row, left out" ], heading("Can't read")
    assert_equal [ [ "└ Row 12 · Cinema · Can't read the amount “abc”" ] ], lines("Can't read")
    assert_select %(section[aria-label="Can't read"] p.text-danger), text: "1 row, left out"
    assert_equal [ "Total", "Matches the Total row in personal.csv", "$4,186.06" ], heading("Total")
    assert_select "p", text: "You can undo the whole import later."
    assert_select "form[action=?] button:not([disabled])", import_transactions_path(import), text: "Import 11 ↵"
  end

  test "rows already here list where they came from, and the total still counts them" do
    have_personal_rows(@user)
    import = @user.start_import(import_file("personal.csv"))

    get edit_import_categories_url(import)

    assert_equal [ "New", "7 rows", "$891.40" ], heading("New")
    assert_equal [ "Already here", "4 rows, skipped", "$3,294.66" ], heading("Already here")
    assert_equal [ [ "└ Row 5 · Oct 2, 2024 · Whole Foods · typed in", "$1,234.56" ], [ "└ Row 8 · Oct 4, 2024 · Trader Joe's · from earlier.csv", "$42.10" ],
                   [ "└ Row 10 · Oct 6, 2024 · Rent · from your bank", "$2,000.00" ], [ "└ Row 11 · Oct 7, 2024 · Groceries · deleted before", "$18.00" ] ], lines("Already here")
    assert_equal [ "Total", "Matches the Total row in personal.csv", "$4,186.06" ], heading("Total")
  end

  test "each list shows its first 20 rows and counts the rest" do
    rows = (1..25).map { |day| "2024-09-#{day.to_s.rjust(2, "0")},Shop #{day},abc\n" }.join
    import = @user.start_import(upload("many.csv", "Date,Name,Amount\n#{rows}"))

    get edit_import_categories_url(import)

    assert_equal [ "Can't read", "25 rows, left out" ], heading("Can't read")
    assert_equal 20, lines("Can't read").size
    assert_select %(section[aria-label="Can't read"] p), text: "And 5 more."
    assert_select "section[aria-label=Total]", count: 0
    assert_select "form[action=?] button[disabled]", import_transactions_path(import), text: "Import 0 ↵"
    assert_select "p", text: "No row can be read. Go back and check the columns."
  end

  test "a Total row that doesn't add up says what it says" do
    import = @user.start_import(upload("short.csv", "Date,Name,Amount\n2024-10-01,Coffee,5.50\n2024-10-02,Lunch,12.00\nTotal,,\"1,800.00\"\n"))

    get edit_import_categories_url(import)

    assert_equal [ "Total", "The Total row in short.csv says $1,800.00", "$17.50" ], heading("Total")
    assert_select "section[aria-label=Total] p.text-danger", text: "The Total row in short.csv says $1,800.00"
  end

  test "a file with no Total row has no check line" do
    import = @user.start_import(upload("names.csv", "Date,Name,Amount\n2024-10-01,Coffee,5.50\n"))

    get edit_import_categories_url(import)

    assert_equal [ "Total", "$5.50" ], heading("Total")
  end

  test "a file with transfers lists them after income, and refunds before" do
    import = @user.start_import(upload("moves.csv", "Date,Name,Category,Amount,Transfer\n2024-10-01,To savings,,500,yes\n2024-10-02,Lunch,Food,-12,\n2024-10-03,Lunch refund,Food,5,\n2024-10-04,Lunch,Food,-12,\n"))

    get edit_import_categories_url(import)

    assert_equal [ [ "└ 2 spent", "−$24.00" ], [ "└ 1 refund", "$5.00" ], [ "└ 1 transfer", "$500.00" ] ], lines("New")
  end

  test "a choice saves and the tally follows it" do
    import = @user.start_import(import_file("personal.csv"))

    patch import_categories_url(import), params: { import: { categories: [ { word: "Coffee", name: "" }, { word: "Groceries", name: "Food" } ] } }

    assert_redirected_to edit_import_categories_url(import)
    follow_redirect!
    assert_select "select[aria-label='What Coffee becomes'] option[selected]", text: "No category"
    assert_select "select[aria-label='What Groceries becomes'] option[selected]", text: "Food"
    assert_equal [ [ "└ 9 spent", "$3,371.56" ], [ "└ 1 income", "−$5.50" ], [ "└ 1 excluded", "$820.00" ] ], lines("New")
  end

  test "a matched word with money in stays out of the fold so its money-in choice shows" do
    import = @user.start_import(upload("food.csv", "Date,Name,Amount,Type,Category\n2024-10-01,Sushi,36.40,Expense,food\n2024-10-02,Sushi refund,10.00,Income,food\n"))

    get edit_import_categories_url(import)

    assert_select "form p", text: "Choose what each category becomes."
    assert_select "select[aria-label='What food becomes'] option[selected]", text: "Food"
    assert_select "select[aria-label='What food money in becomes'] option[selected]", text: "Refund to Food"
    assert_select "button[aria-controls=matched_categories]", count: 0
  end

  test "a money-in choice saves and the tally follows it" do
    import = @user.start_import(import_file("personal.csv"))

    patch import_categories_url(import), params: { import: { categories: [ { word: "Coffee", name: "Coffee", money_in: "Income" } ] } }

    follow_redirect!
    assert_select "select[aria-label='What Coffee money in becomes'] option[selected]", text: "Income"
    assert_equal [ [ "└ 9 spent", "$3,371.56" ], [ "└ 1 income", "−$5.50" ], [ "└ 1 excluded", "$820.00" ] ], lines("New")
  end

  test "Refund to follows the word's category" do
    import = @user.start_import(import_file("personal.csv"))

    patch import_categories_url(import), params: { import: { categories: [ { word: "Coffee", name: "Food", money_in: "" } ] } }

    follow_redirect!
    assert_select "select[aria-label='What Coffee money in becomes'] option[selected]", text: "Refund to Food"
  end

  test "a newer copy of the file counts what's new and what's already here" do
    @user.start_import(import_file("personal.csv")).complete
    newer = @user.start_import(upload("personal.csv", file_fixture("imports/personal.csv").read + "2024-10-11,Blue Bottle,Coffee,5.50,,\n"))

    get edit_import_categories_url(newer)

    assert_equal [ "New", "1 row", "$5.50" ], heading("New")
    assert_equal [ "Already here", "11 rows, skipped", "$4,186.06" ], heading("Already here")
    assert_equal [ "Total", "The Total row in personal.csv says $4,186.06", "$4,191.56" ], heading("Total")
    assert_select "form[action=?] button:not([disabled])", import_transactions_path(newer), text: "Import 1 ↵"
  end

  test "the same file again has nothing new to import and says so" do
    @user.start_import(import_file("personal.csv")).complete
    again = @user.start_import(import_file("personal.csv"))

    get edit_import_categories_url(again)

    assert_select "section[aria-label=New]", count: 0
    assert_equal [ "Already here", "11 rows, skipped", "$4,186.06" ], heading("Already here")
    assert_select "p", text: "Every row in this file is already here."
    assert_select "form[action=?] button[disabled]", import_transactions_path(again), text: "Import 0 ↵"
  end

  test "a file with no category column shows only the preview" do
    import = @user.start_import(upload("names.csv", "Date,Name,Amount\n2024-10-01,Coffee,5.50\n"))

    get edit_import_categories_url(import)

    assert_select "select", count: 0
    assert_equal [ "New", "1 row", "$5.50" ], heading("New")
    assert_equal [ [ "└ 1 spent", "$5.50" ] ], lines("New")
  end

  test "another user's import isn't found" do
    theirs = users(:two).start_import(import_file("personal.csv"))

    get edit_import_categories_url(theirs)
    assert_response :not_found

    patch import_categories_url(theirs), params: { import: { categories: [ { word: "Coffee", name: "" } ] } }
    assert_response :not_found
    assert_equal({}, theirs.reload.category_names)
  end

  private
    def heading(name)
      css_select(%(section[aria-label="#{name}"] > div:first-child p)).map { |paragraph| paragraph.text.squish }
    end

    def lines(name)
      css_select(%(section[aria-label="#{name}"] li)).map { |line| line.css("p").map { |paragraph| paragraph.text.squish } }
    end
end
