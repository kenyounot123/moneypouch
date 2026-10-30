module DemoHelper
  def demo_install_url
    "https://github.com/kenyounot123/moneypouch#getting-started"
  end

  def demo_feedback_url
    "https://github.com/kenyounot123/moneypouch/issues/new"
  end

  def sandbox_deletion_note(user)
    minutes = ((user.expires_at - Time.current) / 1.minute).ceil

    case minutes
    when (60..)
      "Your sandbox is deleted in #{pluralize((minutes / 60.0).ceil, "hour")}."
    when (1..)
      "Your sandbox is deleted in #{pluralize(minutes, "minute")}."
    else
      "Your sandbox is deleted any minute now."
    end
  end

  def not_in_demo_note
    tag.span "Not available in the demo", class: "shrink-0 text-sm whitespace-nowrap text-tertiary"
  end
end
