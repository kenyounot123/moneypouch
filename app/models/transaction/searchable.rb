module Transaction::Searchable
  extend ActiveSupport::Concern

  class_methods do
    def matching(query)
      if query.present?
        pattern = "%#{sanitize_sql_like(query.downcase(:ascii))}%"
        where("lower(transactions.name) LIKE :pattern ESCAPE '\\' OR lower(transactions.note) LIKE :pattern ESCAPE '\\'", pattern:)
      else
        all
      end
    end

    def merchants(limit)
      group(:name).order(Arel.sql("count(*) DESC"), :name).limit(limit).count.map { |name, count| { name:, count: } }
    end

    def last_category_for(name)
      eager_load(:category)
        .where("lower(transactions.name) = ?", name.downcase(:ascii))
        .order(occurred_on: :desc, id: :desc)
        .first&.category
    end

    def name_starting_with(prefix)
      where("lower(transactions.name) LIKE ? ESCAPE '\\'", "#{sanitize_sql_like(prefix.downcase(:ascii))}%")
        .where("length(transactions.name) > ?", prefix.length)
        .group(:name)
        .order(Arel.sql("count(*) DESC, max(transactions.occurred_on) DESC"))
        .pick(:name)
    end
  end
end
