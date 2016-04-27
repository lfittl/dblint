module Dblint
  module Checks
    class LongHeldLock < Base
      class Error < StandardError; end

      def initialize
        @locks_held = {}
        @existing_ids = {}
      end

      def statement_started(_name, _id, _payload)
        # Ignored
      end

      def statement_finished(_name, _id, payload)
        if payload[:sql] == 'BEGIN'
          handle_begin
        elsif payload[:sql] == 'COMMIT'
          handle_commit
        elsif payload[:sql] == 'ROLLBACK'
          # do nothing
        elsif @existing_ids.present?
          increment_locks_held
          add_new_locks_held(payload)
        end
      end

      private

      def increment_locks_held
        @locks_held.each do |_, lock|
          lock[:count] += 1
        end
      end

      def add_new_locks_held(payload)
        locked_table = payload[:sql].match(/^UPDATE\s+"?([\w.]+)"?/i).try(:[], 1)

        return unless locked_table.present?

        bind = payload[:binds].find { |b| b[0].name == 'id' }
        return unless bind.present?

        tuple = [locked_table, bind[1]]

        # We only want tuples that were not created in this transaction
        existing_ids = @existing_ids[tuple[0]]
        return unless existing_ids.present? && existing_ids.include?(tuple[1])

        # We've done two UPDATEs to the same row in this transaction
        return if @locks_held[tuple].present?

        @locks_held[tuple] = {}
        @locks_held[tuple][:sql]   = payload[:sql]
        @locks_held[tuple][:count] = 0
        @locks_held[tuple][:started_at] = Time.now
      end

      def handle_begin
        @locks_held = {}
        @existing_ids = {}

        ActiveRecord::Base.connection.tables.each do |table|
          next if table == 'schema_migrations'
          @existing_ids[table] = ActiveRecord::Base.connection.select_values("SELECT id FROM #{table}", 'DBLINT').map(&:to_i)
        end
      end

      def handle_commit
        @locks_held.each do |table, details|
          next if details[:count] < 10

          main_app_caller = find_main_app_caller(caller)
          next unless main_app_caller.present?

          next if ignored?(main_app_caller)

          error_msg = format("Lock on %s held for %d statements (%0.2f ms) by '%s', transaction started by %s",
                             table.inspect, details[:count], Time.now - details[:started_at], details[:sql],
                             main_app_caller)

          next unless details[:count] > 15

          # We need an explicit begin here since we're interrupting the transaction flow
          ActiveRecord::Base.connection.execute('BEGIN')
          raise Error, error_msg

          # TODO: Add a config setting for enabling this as a warning
          # puts format('Warning: %s', error_msg)
        end
      end
    end
  end
end
