class Transaction::Categorization < Data.define(:category)
  def self.from(params, categories:)
    name = params.expect(categorization: [ :category ])[:category].to_s.squish

    if name.empty?
      none
    else
      new(category: categories.named(name).first || categories.build(name:))
    end
  end

  def self.none
    new(category: nil)
  end

  def none?
    category.nil?
  end
end
