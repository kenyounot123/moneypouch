module SidebarHelper
  def sidebar_state
    if cookies[:sidebar] == "collapsed"
      "collapsed"
    else
      "expanded"
    end
  end

  def sidebar_link_to(label, path, icon:, active: current_page?(path), **options, &block)
    state_classes = active ? "bg-level-3 text-primary" : "text-secondary hover:bg-level-3 hover:text-primary"

    link_to path, data: options[:data], aria: { current: active ? "page" : nil, **options[:aria].to_h }, class: [ "group sidebar-link", state_classes, options[:class] ] do
      safe_join [ icon_tag(icon), tag.span(label, class: "sidebar-label"), (capture(&block) if block) ].compact
    end
  end
end
