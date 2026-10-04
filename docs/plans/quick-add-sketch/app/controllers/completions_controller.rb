# P8. GET /completions
#   { "names": [["Blue Bottle", 41, "2026-09-26"], ...], "categories": ["Food", ...] }
# Tuples keep 2000 names small on the wire; completion_controller.js turns them
# into objects once per fetch. Two queries: names, categories.
#
# Names group by lower(name) so "blue bottle" and "Blue Bottle" are one entry.
# The displayed casing is the latest row's: SQLite returns bare columns from the
# row that satisfies a lone max() aggregate, so `name` comes from max(id).
# Served by index_transactions_on_user_id_and_lower_name_kept.
class CompletionsController < ApplicationController
  def index
    raise NotImplementedError
    # names = Current.user.transactions.where.not(name: "")
    #   .group(Arel.sql("lower(name)"))
    #   .pluck(:name, Arel.sql("count(*)"), Arel.sql("max(occurred_on)"), Arel.sql("max(id)"))
    #   .map { |name, count, latest, _| [name, count, latest] }
    # render json: { names:, categories: Current.user.categories.order(:name).pluck(:name) }
  end
end
