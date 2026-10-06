module WelcomeHelper
  def transactions_total(count, since)
    "#{number_with_delimiter(count)} #{"transaction".pluralize(count)} since #{since.strftime("%b %Y")}"
  end
end
