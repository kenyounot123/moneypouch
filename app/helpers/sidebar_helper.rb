module SidebarHelper
  def sidebar_state
    if cookies[:sidebar] == "collapsed"
      "collapsed"
    else
      "expanded"
    end
  end

  def sidebar_link_to(label, path, icon:, active: current_page?(path))
    state_classes = active ? "bg-level-3 text-primary" : "text-secondary hover:bg-level-3 hover:text-primary"

    link_to path, aria: { current: active ? "page" : nil }, class: [ "group sidebar-link", state_classes ] do
      safe_join [ icon_tag(icon), tag.span(label, class: "sidebar-label") ]
    end
  end
end
