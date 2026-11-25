class User::GetStarted
  Step = Data.define(:name, :done) do
    def done?
      done
    end
  end

  def initialize(user)
    @user = user
  end

  def steps
    @steps ||= [
      Step.new(name: :add, done: @user.added_a_transaction?),
      Step.new(name: :categorize, done: @user.categorized_a_transaction?),
      Step.new(name: :bring_in_history, done: @user.brought_in_history?)
    ]
  end

  def done_count
    steps.count(&:done?)
  end

  def pending?
    !@user.get_started_hidden? && done_count < steps.size
  end
end
