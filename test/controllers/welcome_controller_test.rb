require "test_helper"

class WelcomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "lists the latest kept rows in Recent with this month's count" do
    travel_to Time.utc(2026, 10, 15) do
      users(:one).transactions.create!(name: "Old lunch", amount_in_cents: -1200, occurred_on: "2026-09-30")
      transactions(:paycheck).discard

      get root_url
    end

    assert_equal [ "Blue Bottle", "Old lunch" ], css_select("ul li p.font-medium").map(&:text)
    assert_select "p", text: "1 this month"
  end

  test "says Recent is empty when the user has no kept rows" do
    users(:one).transactions.each(&:discard)

    get root_url

    assert_select "ul li", text: "No transactions yet. Type one above.", count: 1
    assert_select "p", text: "0 this month"
  end

  test "links the total count and first month under Recent" do
    get root_url

    assert_select "a[href='#{transactions_path}']", text: "2 transactions since Oct 2026"
  end

  test "has no count link when the user has no kept rows" do
    users(:one).transactions.each(&:discard)

    get root_url

    assert_select "a[href='#{transactions_path}']", count: 0
  end

  test "marks Overview as the current sidebar page" do
    get root_url

    assert_select "aside a[aria-current=page]", text: "Overview", count: 1
  end

  test "marks the added row, shows the toast, and empties the field" do
    post transactions_url, params: { shorthand: "tea 3", idempotency_key: "key-1" }, headers: { "HTTP_REFERER" => root_url }
    follow_redirect!

    added = Transaction.order(:id).last
    assert_select "##{ActionView::RecordIdentifier.dom_id(added)} .bg-highlight"
    assert_select "#toast_transaction_#{added.id}", text: /Added\s+tea\s+\$3.00\s+Undo\s+Ctrl Z/
    assert_select "input[name=shorthand][value='']"
  end

  test "names the Mac shortcut for a Mac browser" do
    post transactions_url, params: { shorthand: "tea 3", idempotency_key: "key-1" }
    get root_url, headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/130.0" }

    assert_select "[data-composer-target=undo]", text: /⌘Z/
  end

  test "puts an undone shorthand back in the field" do
    delete transaction_url(transactions(:coffee)), headers: { "HTTP_REFERER" => root_url }
    follow_redirect!

    assert_select "input[name=shorthand][value=?]", "Blue Bottle 5.50"
    assert_select "turbo-frame#voucher", text: /Blue Bottle/
  end

  test "gives the bar the user's category names in name order" do
    users(:one).categories.create!(name: "groceries")
    users(:one).categories.create!(name: "Bills")
    users(:two).categories.create!(name: "Secret")

    get root_url

    assert_select "[data-composer-categories-value=?]", '["Bills","Food","groceries"]'
  end
end
