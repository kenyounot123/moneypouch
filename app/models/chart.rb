class Chart
  KINDS = %w[ spending summary ]

  attr_reader :kind

  def initialize(kind)
    @kind = kind.presence_in(KINDS) || "spending"
  end

  def spending?
    kind == "spending"
  end

  def summary?
    kind == "summary"
  end

  def to_param
    unless spending?
      kind
    end
  end
end
