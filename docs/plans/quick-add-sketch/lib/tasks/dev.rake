# P3. rake dev:transactions[N] - N realistic rows for `demo` over the last 12 months.
# Additive (run twice = 2N rows). Categories via find-or-create on the lower(name)
# index, so none duplicate. Rows are written through insert_all in batches (fast),
# with created_at = occurred_on so Transaction#stashed_on matches the date, and
# `line` in absolute form ("Blue Bottle 5.50 #Food 2026-03-14") so `e` edits are
# anchor-independent. A fixed name pool of a few hundred produces history for
# inference and completions; P8 perf needs 2000 distinct names, so N >= 10000 adds
# numbered variants.
namespace :dev do
  task :transactions, [ :count ] => :environment do |_, args|
    raise NotImplementedError
  end
end
