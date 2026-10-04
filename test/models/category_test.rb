require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "one user cannot hold Food and food" do
    assert_raises(ActiveRecord::RecordNotUnique) { users(:one).categories.create!(name: "food") }
  end

  test "two users can each hold Food" do
    assert_equal "Food", users(:two).categories.create!(name: "Food").name
  end

  test "named matches ignoring ASCII case" do
    assert_equal [ "Food" ], users(:one).categories.named("FOOD").pluck(:name)
  end
end
