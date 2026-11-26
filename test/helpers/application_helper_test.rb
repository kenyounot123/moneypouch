require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "colors an example by what it is" do
    assert_dom_equal %(<code class="font-mono text-xs text-category">#food</code>), example_tag("#food", :category)
    assert_dom_equal %(<code class="font-mono text-xs">coffee</code>), example_tag("coffee")
  end

  test "writes style declarations as JSON with dashed property names" do
    assert_equal %({"min-width":"3px","flex":"40 1 0"}), style_declarations(min_width: "3px", flex: "40 1 0")
  end
end
