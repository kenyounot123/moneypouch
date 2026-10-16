require "test_helper"

class Imports::TransactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    travel_to Time.utc(2026, 10, 15, 12)
  end

  test "Import adds the rows and lands on their newest month with a toast that can undo them" do
    import = @user.start_import(import_file("personal.csv"))

    assert_difference -> { @user.transactions.count }, 11 do
      post import_transactions_url(import)
    end

    assert_redirected_to transactions_url(month: "2024-10")
    follow_redirect!
    assert_select "nav[aria-label=Month] [aria-current=true]", text: "October 2024"
    assert_select "[data-controller=toast] span", text: "Imported 11 transactions from personal.csv"
    assert_select "[data-controller=toast] form[action=?][data-turbo-confirm=?] button", import_path(import), "Remove the 11 transactions from personal.csv?", text: "Undo"
    assert_select "p", text: "Rent"
  end

  test "pressing Import again adds nothing more and lands on the Import page" do
    import = @user.start_import(import_file("personal.csv"))
    post import_transactions_url(import)

    assert_no_difference -> { Transaction.count } do
      post import_transactions_url(import)
    end
    assert_redirected_to new_import_url
  end

  test "an import with nothing new leaves nothing behind and lands on the Import page" do
    @user.start_import(import_file("personal.csv")).complete
    again = @user.start_import(import_file("personal.csv"))

    post import_transactions_url(again)

    assert_redirected_to new_import_url
    assert_not Import.exists?(again.id)
  end

  test "another user's import isn't found" do
    theirs = users(:two).start_import(import_file("personal.csv"))

    post import_transactions_url(theirs)

    assert_response :not_found
    assert theirs.reload.draft?
  end
end
