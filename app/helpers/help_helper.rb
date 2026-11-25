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

  def help_glossary
    "help/pages/#{help_page}"
  end

  def help_state
    if cookies[:help] == "open"
      "open"
    else
      "closed"
    end
  end

  def help_drawer?
    controller_path != "help"
  end

  def help_opener_data
    if help_drawer?
      { help_target: "opener", action: "sidebar#close help#open" }
    end
  end

  def help_section_id(section)
    section.parameterize
  end

  def square_tag(kind)
    case kind
    when :gold
      tag.span class: "inline-block size-1.5 rounded-[1px] bg-highlight align-middle"
    when :dashed
      tag.span class: "inline-block size-2.5 rounded-[1px] bg-data-soft align-middle outline-1 outline-offset-1 outline-dashed outline-(--background-color-data)"
    end
  end

  def category_link_tag(name)
    tag.span name, class: "underline decoration-dotted underline-offset-3"
  end
end
