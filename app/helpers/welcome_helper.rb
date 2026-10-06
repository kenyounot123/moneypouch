module WelcomeHelper
  def transactions_total(count, since)
    "#{pluralize(count, "transaction")} since #{since.strftime("%b %Y")}"
  end
end
