module SidebarHelper
  ICONS = {
    overview: '<path d="M2.75 6.75 8 2.5l5.25 4.25v6a.75.75 0 0 1-.75.75h-2.75v-4h-3.5v4H3.5a.75.75 0 0 1-.75-.75z"/>',
    transactions: '<path d="M2.5 5.25h11M10.75 2.5l2.75 2.75L10.75 8M13.5 10.75h-11M5.25 8 2.5 10.75l2.75 2.75"/>',
    categories: '<path d="M2.5 3.5a1 1 0 0 1 1-1h4.09a1 1 0 0 1 .7.29l4.92 4.92a1 1 0 0 1 0 1.41l-4.09 4.09a1 1 0 0 1-1.41 0L2.79 8.29a1 1 0 0 1-.29-.7z"/><circle cx="5.5" cy="5.5" r="1" fill="currentColor" stroke="none"/>',
    trends: '<path d="M2.5 2.5v9.5a1.5 1.5 0 0 0 1.5 1.5h9.5M5.5 10l2.5-3 2 2 3.5-4.5"/>',
    settings: '<path d="M12.90 7.01L14.45 7.16L14.45 8.84L12.90 8.99L12.17 10.76L13.15 11.96L11.96 13.15L10.76 12.17L8.99 12.90L8.84 14.45L7.16 14.45L7.01 12.90L5.24 12.17L4.04 13.15L2.85 11.96L3.83 10.76L3.10 8.99L1.55 8.84L1.55 7.16L3.10 7.01L3.83 5.24L2.85 4.04L4.04 2.85L5.24 3.83L7.01 3.10L7.16 1.55L8.84 1.55L8.99 3.10L10.76 3.83L11.96 2.85L13.15 4.04L12.17 5.24Z"/><circle cx="8" cy="8" r="2"/>',
    toggle: '<rect x="2" y="2.75" width="12" height="10.5" rx="2"/><path d="M6.25 2.75v10.5"/>'
  }.freeze

  SIDEBAR_LINK = "group relative flex items-center gap-2.5 rounded-md px-3 py-[9px] " \
    "in-data-[sidebar=collapsed]:h-9 in-data-[sidebar=collapsed]:w-10 in-data-[sidebar=collapsed]:justify-center in-data-[sidebar=collapsed]:px-0"

  SIDEBAR_LABEL = "in-data-[sidebar=collapsed]:pointer-events-none in-data-[sidebar=collapsed]:absolute " \
    "in-data-[sidebar=collapsed]:top-1/2 in-data-[sidebar=collapsed]:left-full in-data-[sidebar=collapsed]:ml-2 " \
    "in-data-[sidebar=collapsed]:-translate-y-1/2 in-data-[sidebar=collapsed]:rounded-sm " \
    "in-data-[sidebar=collapsed]:border in-data-[sidebar=collapsed]:border-primary " \
    "in-data-[sidebar=collapsed]:bg-level-2 in-data-[sidebar=collapsed]:px-2 in-data-[sidebar=collapsed]:py-1 " \
    "in-data-[sidebar=collapsed]:text-sm in-data-[sidebar=collapsed]:whitespace-nowrap " \
    "in-data-[sidebar=collapsed]:text-primary in-data-[sidebar=collapsed]:shadow-control " \
    "in-data-[sidebar=collapsed]:opacity-0 in-data-[sidebar=collapsed]:group-hover:opacity-100 " \
    "in-data-[sidebar=collapsed]:group-focus-visible:opacity-100"

  def sidebar_state
    if cookies[:sidebar] == "collapsed"
      "collapsed"
    else
      "expanded"
    end
  end

  def sidebar_icon(name)
    tag.svg(
      ICONS.fetch(name).html_safe,
      width: 16,
      height: 16,
      viewBox: "0 0 16 16",
      fill: "none",
      stroke: "currentColor",
      "stroke-width": 1.5,
      "stroke-linecap": "round",
      "stroke-linejoin": "round",
      class: "shrink-0",
      aria: { hidden: true }
    )
  end

  def sidebar_link_to(label, path, icon:)
    active = current_page?(path)
    state_classes = active ? "bg-level-3 font-medium text-primary" : "text-secondary hover:bg-level-3 hover:text-primary"

    link_to path, aria: { current: active ? "page" : nil }, class: [ SIDEBAR_LINK, state_classes ] do
      safe_join [ sidebar_icon(icon), tag.span(label, class: SIDEBAR_LABEL) ]
    end
  end
end
