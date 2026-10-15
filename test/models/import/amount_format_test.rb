require "test_helper"

class Import::AmountFormatTest < ActiveSupport::TestCase
  test "a column writing cents after a comma reads European amounts" do
    format = Import::AmountFormat.for([ "-3,50", "-1.234,56", "2.500,00" ])

    assert_equal [ ",", -350, -123_456, 250_000, 1_250, -700 ],
      [ format.decimal_mark, *[ "-3,50", "-1.234,56", "2.500,00", "12,50 €", "−7,00" ].map { |text| format.read(text) } ]
  end

  test "a column writing cents after a point, or no cents at all, reads the dot as the decimal mark" do
    assert_equal ".", Import::AmountFormat.for([ "1,234.56", "12.50", "5" ]).decimal_mark
    assert_equal ".", Import::AmountFormat.for([ "1,234", "5" ]).decimal_mark
    assert_equal ".", Import::AmountFormat.for([ BigDecimal("12.5") ]).decimal_mark
  end

  test "signs read as written: a leading or trailing minus and parentheses are negative" do
    format = Import::AmountFormat.new(".")

    assert_equal [ 550, -550, -550, -1_200, -1_200, -1_200, 1_200 ],
      [ "5.50", "-5.50", "5.50-", "(12.00)", "-$12", "$-12", "+12" ].map { |text| format.read(text) }
  end

  test "currency marks, codes, and thousands separators are dropped" do
    format = Import::AmountFormat.new(".")

    assert_equal [ 123_456, 1_200, 1_200, 1_240, 123_450 ],
      [ "$1,234.56", "USD 12.00", "12.00 USD", "£12.40 ", "1'234.50" ].map { |text| format.read(text) }
  end

  test "an Excel number rounds to cents half to even, like a bank amount" do
    format = Import::AmountFormat.new(".")

    assert_equal [ 123_456, 0, 2, 41_200 ],
      [ BigDecimal("1234.5599999999999"), BigDecimal("0.005"), BigDecimal("0.015"), BigDecimal("412") ].map { |cell| format.read(cell) }
  end

  test "text that isn't money doesn't read" do
    format = Import::AmountFormat.new(".")

    assert_equal [ nil, nil, nil, nil, nil, 0 ],
      [ "abc", "-", "2024-10-02", Date.new(2024, 10, 2), true, "0" ].map { |cell| format.read(cell) }
  end
end
