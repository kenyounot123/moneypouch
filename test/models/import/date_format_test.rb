require "test_helper"

class Import::DateFormatTest < ActiveSupport::TestCase
  test "a day over 12 in the first part makes the whole column day first" do
    format = Import::DateFormat.for([ "01/02/2024", "13/02/2024", "05/03/2024" ])

    assert_equal "day_first", format.name
    assert_equal [ Date.new(2024, 2, 1), Date.new(2024, 2, 13) ], [ format.read("01/02/2024"), format.read("13/02/2024") ]
  end

  test "a day over 12 in the second part makes the whole column month first" do
    format = Import::DateFormat.for([ "01/02/2024", "04/13/2024" ])

    assert_equal "month_first", format.name
    assert_equal Date.new(2024, 1, 2), format.read("01/02/2024")
  end

  test "a column where every date could be either way reads month first" do
    format = Import::DateFormat.for([ "01/02/2024", "03/04/2024" ])

    assert_equal [ "month_first", Date.new(2024, 3, 4) ], [ format.name, format.read("03/04/2024") ]
  end

  test "the format the most cells agree on wins, and a cell written another way doesn't read" do
    format = Import::DateFormat.for([ "2024-10-01", "2024-10-02", "10/03/2024" ])

    assert_equal [ "iso", Date.new(2024, 10, 2), nil ], [ format.name, format.read("2024-10-02"), format.read("10/03/2024") ]
  end

  test "each way of writing a date reads, with any time of day dropped" do
    assert_equal Date.new(2024, 10, 2), Import::DateFormat.for([ "2024/10/02" ]).read("2024-10-02T14:33:00Z")
    assert_equal Date.new(2024, 10, 2), Import::DateFormat.for([ "02.10.2024", "15.10.2024" ]).read("02.10.2024")
    assert_equal Date.new(2024, 10, 2), Import::DateFormat.for([ "10/02/24" ]).read("10/02/24 2:33 PM")
    assert_equal Date.new(2024, 10, 2), Import::DateFormat.for([ "Oct. 2, 2024", "October 15 2024" ]).read("Oct. 2, 2024")
    assert_equal Date.new(2024, 10, 2), Import::DateFormat.for([ "02-Oct-24", "15 Oct 2024" ]).read("02-Oct-24")
  end

  test "typed dates read under any format and an Excel serial number reads as its day" do
    format = Import::DateFormat.for([ Date.new(2024, 1, 1) ])

    assert_equal [ Date.new(2024, 1, 1), Date.new(2024, 1, 1), nil ],
      [ format.read(Date.new(2024, 1, 1)), format.read(BigDecimal("45292")), format.read(BigDecimal("5.5")) ]
  end

  test "an impossible day or one far outside a life of spending doesn't read" do
    travel_to Date.new(2026, 10, 15)
    format = Import::DateFormat.new("iso")

    assert_equal [ nil, nil, nil, Date.new(2027, 10, 15) ],
      [ format.read("2024-02-30"), format.read("1969-12-31"), format.read("2027-10-16"), format.read("2027-10-15") ]
  end

  test "a blank cell or text without a digit can't be a date" do
    assert_equal [ true, true, true, false, false, false ],
      [ nil, "Total", true, "2024-10-02", Date.new(2024, 10, 2), BigDecimal("45292") ].map { |cell| Import::DateFormat.dateless?(cell) }
  end
end
