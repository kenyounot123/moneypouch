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
        return {}
      end

      imported_before = ids_by_key(rows)
      kept_alike = kept_ids_by_identity(rows)
      copies_so_far = Hash.new(0)

      found = rows.filter_map do |row|
        copies_so_far[row.identity] += 1
        id = imported_before[row.key] || kept_alike.dig(row.identity, copies_so_far[row.identity] - 1)
        [ row, id ] if id
      end

      transactions = found.map(&:last).each_slice(1_000).flat_map { |ids| where(id: ids).includes(:bank_transaction, :import).to_a }.index_by(&:id)
      found.to_h { |row, id| [ row, transactions.fetch(id) ] }
    end

    private
      def ids_by_key(rows)
        rows.map(&:key).each_slice(1_000).flat_map { |keys| where(idempotency_key: keys).pluck(:idempotency_key, :id) }.to_h
      end

      def kept_ids_by_identity(rows)
        kept = self.kept.occurred_in(Range.new(*rows.map(&:occurred_on).minmax)).order(:id).pluck(:id, :occurred_on, :amount_in_cents, :name)
        kept.group_by { |_, occurred_on, amount_in_cents, name| Import::Row.identity(occurred_on:, amount_in_cents:, name:) }.transform_values { |group| group.map(&:first) }
      end
  end
end
