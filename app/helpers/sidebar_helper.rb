module SidebarHelper
  SIDEBAR_LINK = "group relative flex items-center gap-2.5 rounded-md px-3 py-[9px] " \
    "md:in-data-[sidebar=collapsed]:h-9 md:in-data-[sidebar=collapsed]:w-10 md:in-data-[sidebar=collapsed]:justify-center md:in-data-[sidebar=collapsed]:px-0"

  SIDEBAR_LABEL = "md:in-data-[sidebar=collapsed]:pointer-events-none md:in-data-[sidebar=collapsed]:absolute " \
    "md:in-data-[sidebar=collapsed]:top-1/2 md:in-data-[sidebar=collapsed]:left-full md:in-data-[sidebar=collapsed]:ml-2 " \
    "md:in-data-[sidebar=collapsed]:-translate-y-1/2 md:in-data-[sidebar=collapsed]:rounded-sm " \
    "md:in-data-[sidebar=collapsed]:border md:in-data-[sidebar=collapsed]:border-primary " \
    "md:in-data-[sidebar=collapsed]:bg-level-2 md:in-data-[sidebar=collapsed]:px-2 md:in-data-[sidebar=collapsed]:py-1 " \
    "md:in-data-[sidebar=collapsed]:text-sm md:in-data-[sidebar=collapsed]:whitespace-nowrap " \
    "md:in-data-[sidebar=collapsed]:text-primary md:in-data-[sidebar=collapsed]:shadow-control " \
    "md:in-data-[sidebar=collapsed]:opacity-0 md:in-data-[sidebar=collapsed]:group-hover:opacity-100 " \
    "md:in-data-[sidebar=collapsed]:group-focus-visible:opacity-100"

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
