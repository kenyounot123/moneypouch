require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "colors an example by what it is" do
    assert_dom_equal %(<code class="font-mono text-xs text-category">#food</code>), example_tag("#food", :category)
    assert_dom_equal %(<code class="font-mono text-xs">coffee</code>), example_tag("coffee")
  end
end
