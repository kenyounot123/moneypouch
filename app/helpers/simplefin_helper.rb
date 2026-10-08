module SimplefinHelper
  SIMPLEFIN_URL = "https://bridge.simplefin.org"
  SIMPLEFIN_CREATE_URL = "https://bridge.simplefin.org/simplefin/create"

  OUTLINE_BUTTON = "ml-auto flex shrink-0 cursor-pointer items-center gap-1.5 rounded-md border border-primary bg-level-2 px-3 py-1.5 " \
    "text-sm font-medium whitespace-nowrap text-primary shadow-control hover:bg-level-1"

  HEADER_BUTTON = "cursor-pointer text-sm font-medium text-secondary hover:text-primary disabled:cursor-default disabled:text-tertiary"

  def link_to_simplefin(label, url = SIMPLEFIN_URL)
    link_to url, target: "_blank", rel: "noopener", class: OUTLINE_BUTTON do
      safe_join [ label, external_arrow ]
    end
  end

  def external_arrow
    tag.svg(
      tag.path(d: "M4 2h6v6M10 2L3 9"),
      width: 12,
      height: 12,
      viewBox: "0 0 12 12",
      fill: "none",
      stroke: "currentColor",
      "stroke-width": 1.4,
      "stroke-linecap": "round",
      "stroke-linejoin": "round",
      class: "shrink-0 text-secondary",
      aria: { hidden: true }
    )
  end

  def balance(cents)
    if cents
      number_to_currency(cents.to_d / 100)
    end
  end

  def synced_ago(time)
    minutes = ((Time.current - time) / 60).floor

    if minutes < 1
      "Synced just now"
    elsif minutes < 60
      "Synced #{minutes} min ago"
    elsif minutes < 24 * 60
      "Synced #{minutes / 60} hr ago"
    else
      "Synced #{short_date time.to_date}"
    end
  end
end
