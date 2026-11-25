module ApplicationHelper
  EXAMPLE_COLORS = { amount: "text-amount", money_in: "text-success", date: "text-date", category: "text-category" }.freeze

  def icon_tag(name, **options)
    tag.span class: class_names("icon icon--#{name}", options.delete(:class)), aria: { hidden: true }, **options
  end

  def example_tag(text, kind = nil)
    tag.code text, class: class_names("font-mono text-xs", EXAMPLE_COLORS[kind])
  end
end
