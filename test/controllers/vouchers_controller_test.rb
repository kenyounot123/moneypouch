require "test_helper"

class VouchersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "holds back ok and the missing amount while the shorthand has none" do
    get voucher_url(shorthand: "coffee")

    assert_response :success
    assert_select "turbo-frame#voucher", text: /\A\s*Uncategorized · Today\s+format:/
  end

  test "sums up what the shorthand would save without repeating the name" do
    get voucher_url(shorthand: "Blue Bottle +2400 yesterday")

    assert_select "turbo-frame#voucher [data-inferred-category=Food]", text: /\A\s*ok · \+\$2,400.00 · Food · Yesterday\s+format:/
  end

  test "marks where the amount, date, and category sit, counting as the field does" do
    get voucher_url(shorthand: "🍩 Blue Bottle 5.50 @yesterday #food")
    assert_select "[data-marks=?]", [ [ "amount", 15, 19 ], [ "date", 20, 30 ], [ "category", 31, 36 ] ].to_json

    get voucher_url(shorthand: "paycheck +2400 @")
    assert_select "[data-marks=?]", [ [ "money_in", 9, 14 ], [ "date", 15, 16 ] ].to_json
  end

  test "puts money in with no category in Income, and leaves money out Uncategorized" do
    get voucher_url(shorthand: "Bonus +2000")
    assert_select "turbo-frame#voucher", text: /ok · \+\$2,000.00 · Income · Today/

    get voucher_url(shorthand: "Parking 8")
    assert_select "turbo-frame#voucher", text: /ok · \$8.00 · Uncategorized · Today/
  end

  test "marks a category the user has not saved" do
    get voucher_url(shorthand: "lunch 12 #brandnew")

    assert_select "turbo-frame#voucher", text: /New category\s+brandnew/
    assert_select "[data-inferred-category]", count: 0
  end

  test "never shows another user's categories" do
    sign_in_as(users(:two))
    get voucher_url(shorthand: "Blue Bottle 6")

    assert_select "turbo-frame#voucher", text: /Uncategorized/
    assert_select "turbo-frame#voucher", text: /Food/, count: 0
  end

  test "reads today in the browser's time zone" do
    travel_to Time.utc(2026, 10, 4, 12) do
      cookies[:time_zone] = "Pacific/Kiritimati"
      get voucher_url(shorthand: "tea 3 oct 4")
      assert_select "turbo-frame#voucher", text: /Yesterday/

      cookies[:time_zone] = "Not/AZone"
      get voucher_url(shorthand: "tea 3 oct 4")
      assert_select "turbo-frame#voucher", text: /Today/
    end
  end

  test "shows only the format for empty shorthand" do
    get voucher_url(shorthand: "")

    assert_select "turbo-frame#voucher", text: /\A\s*format: coffee 5.50 @yesterday #food\s+money in: paycheck \+2400\s*\z/
  end

  test "offers a used name only when asked" do
    get voucher_url(shorthand: "blu", complete: "1")
    assert_select "[data-shorthand='blu'][data-completion='Blue Bottle'][data-inferred-category=Food]", text: /Food · Today/

    get voucher_url(shorthand: "Blu")
    assert_select "[data-completion]", count: 0
  end

  test "infers the category for shorthand ending in a bare hash" do
    get voucher_url(shorthand: "Blue Bottle 6.40 #")

    assert_select "[data-inferred-category=Food]", text: /ok · \$6.40 · Food/
  end
end
