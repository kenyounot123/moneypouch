require "test_helper"

class Transaction::SortTest < ActiveSupport::TestCase
  test "reads the column and direction from the params" do
    assert_equal [ "name", "desc" ], pair(parse("name", "desc"))
    assert_equal [ "date", "asc" ], pair(parse("date", "asc"))
    assert_equal [ "amount", "asc" ], pair(parse("amount", "asc"))
  end

  test "a column without a direction takes its default, and so does one with a direction that makes no sense" do
    assert_equal [ "date", "desc" ], pair(parse("date", nil))
    assert_equal [ "name", "asc" ], pair(parse("name", nil))
    assert_equal [ "category", "asc" ], pair(parse("category", "sideways"))
    assert_equal [ "account", "asc" ], pair(parse("account", ""))
    assert_equal [ "amount", "asc" ], pair(parse("amount", [ "desc" ]))
  end

  test "an unknown column falls back to the newest first" do
    assert_equal [ "date", "desc" ], pair(parse(nil, nil))
    assert_equal [ "date", "desc" ], pair(parse("balance", "asc"))
    assert_equal [ "date", "desc" ], pair(parse("name; DROP TABLE transactions", "asc"))
    assert_equal [ "date", "desc" ], pair(parse({ "name" => "asc" }, "asc"))
  end

  test "only the date sorts group the list by day" do
    assert_equal [ true, true ], [ parse("date", "desc"), parse("date", "asc") ].map { |sort| sort.grouped_by_day? }
    assert_equal [ false ], %w[ name category account amount ].map { |key| parse(key, nil).grouped_by_day? }.uniq
  end

  test "a header that is already the sort flips its direction" do
    assert_equal [ "date", "asc" ], pair(parse("date", "desc").toggle("date"))
    assert_equal [ "date", "desc" ], pair(parse("date", "asc").toggle("date"))
    assert_equal [ "name", "desc" ], pair(parse("name", "asc").toggle("name"))
    assert_equal [ "amount", "asc" ], pair(parse("amount", "desc").toggle("amount"))
  end

  test "any other header starts at its column's default direction" do
    sort = parse("name", "desc")

    assert_equal [ "date", "desc" ], pair(sort.toggle("date"))
    assert_equal [ "category", "asc" ], pair(sort.toggle("category"))
    assert_equal [ "account", "asc" ], pair(sort.toggle("account"))
    assert_equal [ "amount", "asc" ], pair(sort.toggle("amount"))
    assert_equal [ "date", "desc" ], pair(sort.toggle("balance"))
  end

  test "the default sort has no params, so its links stay clean" do
    assert_equal({}, Transaction::Sort.default.params)
    assert_equal({}, parse("date", "desc").params)
    assert_equal({}, parse("nonsense", "asc").params)
  end

  test "any other sort names its column, and its direction only when it is not the column's default" do
    assert_equal({ sort: "date", direction: "asc" }, parse("date", "asc").params)
    assert_equal({ sort: "name" }, parse("name", "asc").params)
    assert_equal({ sort: "name", direction: "desc" }, parse("name", "desc").params)
    assert_equal({ sort: "amount" }, parse("amount", nil).params)
  end

  test "params read back as the same sort" do
    %w[ date name category account amount ].product(%w[ asc desc ]).each do |key, direction|
      sort = parse(key, direction)

      assert_equal sort, Transaction::Sort.parse(sort.params[:sort], sort.params[:direction]), "#{key} #{direction}"
    end
  end

  private
    def parse(key, direction)
      Transaction::Sort.parse(key, direction)
    end

    def pair(sort)
      [ sort.key, sort.direction ]
    end
end
