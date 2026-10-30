module DemoHelper
  def demo_install_url
    "https://github.com/kenyounot123/moneypouch#getting-started"
  end

  def demo_feedback_url
    "https://github.com/kenyounot123/moneypouch/issues/new"
  end

  def not_in_demo_note
    tag.span "Not available in the demo", class: "shrink-0 text-sm whitespace-nowrap text-tertiary"
  end
end
