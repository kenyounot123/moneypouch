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
    assert_select "select[aria-label='What Coffee becomes'][onchange='this.form.requestSubmit()'] option[selected][value=Coffee]", text: "New category"
    assert_equal [ "New category", "Food", "Income", "No category" ], css_select("select[aria-label='What Coffee becomes'] option").map(&:text)
    assert_select "button[aria-controls=matched_categories][aria-expanded=false]", text: /food matched\s+Show/
    assert_select "#matched_categories[hidden] select[aria-label='What food becomes'] option[selected]", text: "Food"
    assert_equal [ "Food", "Income", "No category" ], css_select("select[aria-label='What food becomes'] option").map(&:text)
    assert_select "form[action=?] button", import_path(import), text: "Cancel"
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
    assert_select "select[aria-label='What Coffee money in becomes'][onchange='this.form.requestSubmit()'] option[selected]", text: "Refund to Coffee"
    assert_equal [ "Income", "Refund to Coffee" ], css_select("select[aria-label='What Coffee money in becomes'] option").map(&:text)
    assert_select "select[aria-label^='What Groceries money in']", count: 0
  end

  test "the tally counts what Import adds, and Can't read lists the rows it leaves out" do
    import = @user.start_import(import_file("personal.csv"))

    get edit_import_categories_url(import)

    assert_equal [ [ "9", "Spent" ], [ "1", "Refunds" ], [ "0", "Income" ], [ "1", "Excluded" ], [ "1", "Can't read" ] ], tally
    assert_select "p", text: "Refunds lower spending in their category."
    assert_select "#unreadable_rows[hidden] li", text: /Row 12\s+Can't read the amount “abc”/
    assert_select "p", text: "You can undo the whole import later."
    assert_select "form[action=?] button:not([disabled])", import_transactions_path(import), text: "Import 11 ↵"
  end

  test "a file with transfers counts them on their own, five to a row" do
    import = @user.start_import(upload("moves.csv", "Date,Name,Amount,Transfer\n2024-10-01,To savings,500,yes\n2024-10-02,Blue Bottle,5.50,\n"))

    get edit_import_categories_url(import)

    assert_equal [ [ "1", "Spent" ], [ "0", "Income" ], [ "1", "Transfers" ], [ "0", "Excluded" ] ], tally
    assert_select "dl.grid-cols-3.\\@lg\\:grid-cols-5"
  end

  test "a file with refunds and transfers counts six to a row" do
    import = @user.start_import(upload("moves.csv", "Date,Name,Category,Amount,Transfer\n2024-10-01,To savings,,500,yes\n2024-10-02,Lunch,Food,-12,\n2024-10-03,Lunch refund,Food,5,\n"))

    get edit_import_categories_url(import)

    assert_equal [ [ "1", "Spent" ], [ "1", "Refunds" ], [ "0", "Income" ], [ "1", "Transfers" ], [ "0", "Excluded" ] ], tally
    assert_select "dl.grid-cols-3.\\@lg\\:grid-cols-6"
  end

  test "a choice saves and the tally follows it" do
    import = @user.start_import(import_file("personal.csv"))

    patch import_categories_url(import), params: { import: { categories: [ { word: "Coffee", name: "" }, { word: "Groceries", name: "Food" } ] } }

    assert_redirected_to edit_import_categories_url(import)
    follow_redirect!
    assert_select "select[aria-label='What Coffee becomes'] option[selected]", text: "No category"
    assert_select "select[aria-label='What Groceries becomes'] option[selected]", text: "Food"
    assert_equal [ [ "9", "Spent" ], [ "1", "Income" ], [ "1", "Excluded" ], [ "1", "Can't read" ] ], tally
    assert_select "p", text: "Money in with no category counts as income."
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
    assert_equal [ [ "9", "Spent" ], [ "1", "Income" ], [ "1", "Excluded" ], [ "1", "Can't read" ] ], tally
    assert_select "p", text: "Money in with no category counts as income."
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

    assert_equal [ [ "1", "New" ], [ "11", "Already here" ], [ "1", "Can't read" ] ], tally
    assert_select "p", text: "Rows you added before are skipped."
    assert_select "form[action=?] button:not([disabled])", import_transactions_path(newer), text: "Import 1 ↵"
  end

  test "the same file again has nothing new to import and says so" do
    @user.start_import(import_file("personal.csv")).complete
    again = @user.start_import(import_file("personal.csv"))

    get edit_import_categories_url(again)

    assert_equal [ [ "0", "New" ], [ "11", "Already here" ], [ "1", "Can't read" ] ], tally
    assert_select "p", text: "Every row in this file is already here."
    assert_select "form[action=?] button[disabled]", import_transactions_path(again), text: "Import 0 ↵"
  end

  test "a file with no category column shows only the tally" do
    import = @user.start_import(upload("names.csv", "Date,Name,Amount\n2024-10-01,Coffee,5.50\n"))

    get edit_import_categories_url(import)

    assert_select "select", count: 0
    assert_equal [ [ "1", "Spent" ], [ "0", "Income" ], [ "0", "Excluded" ] ], tally
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
    def tally
      css_select("dl > div").map { |stat| [ stat.at_css("dd").text, stat.at_css("dt").text.strip ] }
    end
end
