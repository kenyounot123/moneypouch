require "test_helper"

class Transaction::CategorizationTest < ActiveSupport::TestCase
  test "is a category, a transfer, or none" do
    food = categories(:food)

    assert_equal [ food, false, false ], read(Transaction::Categorization.new(category: food))
    assert_equal [ nil, true, false ], read(Transaction::Categorization.transfer)
    assert_equal [ nil, false, true ], read(Transaction::Categorization.none)
  end

  test "cannot be a category and a transfer at once" do
    assert_raises(ArgumentError) { Transaction::Categorization.new(category: categories(:food), transfer: true) }
  end

  test "reads the picker's transfer choice over a name" do
    categorization = Transaction::Categorization.from(params(category: "Food", transfer: "1"), categories: users(:one).categories)

    assert_equal [ nil, true, false ], read(categorization)
  end

  private
    def read(categorization)
      [ categorization.category, categorization.transfer?, categorization.none? ]
    end

    def params(**choice)
      ActionController::Parameters.new(categorization: choice)
    end
end
