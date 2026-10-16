module SidebarHelper
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

  def sidebar_link_to(label, path, icon:, active: current_page?(path))
    state_classes = active ? "bg-level-3 font-medium text-primary" : "text-secondary hover:bg-level-3 hover:text-primary"

    link_to path, aria: { current: active ? "page" : nil }, class: [ SIDEBAR_LINK, state_classes ] do
      safe_join [ icon_tag(icon), tag.span(label, class: SIDEBAR_LABEL) ]
    end
  end
end
