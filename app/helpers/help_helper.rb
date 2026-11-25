module HelpHelper
  PAGES = {
    "welcome" => "overview",
    "transactions" => "transactions",
    "categories" => "categories",
    "trends" => "trends",
    "imports" => "import",
    "imports/columns" => "import",
    "imports/categories" => "import",
    "simplefin/reviews" => "review",
    "settings" => "settings",
    "simplefin/accesses" => "settings"
  }.freeze

  def help_page
    PAGES.fetch(controller_path, "overview")
  end

  def help_section_id(section)
    section.parameterize
  end

  def square_tag(kind)
    case kind
    when :gold
      tag.span class: "block size-1.5 rounded-[1px] bg-highlight"
    when :dashed
      tag.span class: "block size-2.5 rounded-[1px] bg-data-soft outline-1 outline-offset-1 outline-dashed outline-(--background-color-data)"
    end
  end

  def category_link_tag(name)
    tag.span name, class: "underline decoration-dotted underline-offset-3"
  end
end
