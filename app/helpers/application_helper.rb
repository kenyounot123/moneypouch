module ApplicationHelper
  def icon_tag(name, **options)
    tag.span class: class_names("icon icon--#{name}", options.delete(:class)), aria: { hidden: true }, **options
  end
end
