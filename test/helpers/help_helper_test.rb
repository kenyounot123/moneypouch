require "test_helper"

class HelpHelperTest < ActionView::TestCase
  test "every page that has help has a glossary" do
    HelpHelper::PAGES.values.uniq.each do |page|
      assert_predicate render(partial: "help/pages/#{page}").strip, :present?, "#{page} has no glossary"
    end
  end

  test "maps each controller to the page that explains it" do
    {
      "welcome" => "overview", "transactions" => "transactions", "categories" => "categories", "trends" => "trends",
      "imports" => "import", "imports/columns" => "import", "imports/categories" => "import",
      "simplefin/reviews" => "review", "settings" => "settings", "simplefin/accesses" => "settings"
    }.each do |controller_path, page|
      controller.define_singleton_method(:controller_path) { controller_path }
      assert_equal page, help_page, controller_path
    end
  end

  test "an unknown controller gets the overview" do
    controller.define_singleton_method(:controller_path) { "passwords" }
    assert_equal "overview", help_page
  end
end
