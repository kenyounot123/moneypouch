module Transaction::Importable
  extend ActiveSupport::Concern

  included do
    belongs_to :import, optional: true
  end

  class_methods do
    def import(rows, import:)
      rows.each_slice(500).sum do |slice|
        attributes = slice.map do |row|
          {
            import_id: import.id,
            idempotency_key: row.key,
            name: row.name,
            occurred_on: row.occurred_on,
            amount_in_cents: row.amount_in_cents,
            category_id: yield(row)&.id,
            transfer: row.transfer?,
            excluded: row.excluded?,
            note: normalize_value_for(:note, row.note)
          }
        end

        insert_all(attributes, returning: :id).length
      end
    end

    # Reads discarded rows too, so a row deleted after one import stays out of the next.
    def already_here(rows)
      if rows.none?
        return []
      end

      imported_before = imported_keys(rows)
      kept_alike = kept_counts_by_identity(rows)
      copies_so_far = Hash.new(0)

      rows.select do |row|
        copies_so_far[row.identity] += 1
        imported_before.include?(row.key) || copies_so_far[row.identity] <= kept_alike.fetch(row.identity, 0)
      end
    end

    private
      def imported_keys(rows)
        rows.map(&:key).each_slice(1_000).flat_map { |keys| where(idempotency_key: keys).pluck(:idempotency_key) }.to_set
      end

      def kept_counts_by_identity(rows)
        kept = self.kept.occurred_in(Range.new(*rows.map(&:occurred_on).minmax)).pluck(:occurred_on, :amount_in_cents, :name)
        kept.map { |occurred_on, amount_in_cents, name| Import::Row.identity(occurred_on:, amount_in_cents:, name:) }.tally
      end
  end
end
