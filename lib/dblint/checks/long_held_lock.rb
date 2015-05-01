module Dblint
  module Checks
    module LongHeldLock
      extend self

      class Error < StandardError; end

      def statement_started(_name, _id, _payload)
        # Ignored
      end

      def statement_finished(_name, _id, payload)
        @stats ||= {}

        connid = payload[:connection_id]

        if payload[:sql] == 'BEGIN'
          handle_begin(connid)
        elsif payload[:sql] == 'COMMIT'
          handle_commit(connid)
        elsif payload[:sql] == 'ROLLBACK'
          # do nothing
        elsif @stats[connid].present?
          increment_locks_held(connid)
          add_new_locks_held(connid, payload)
        end
      end

      private

      def increment_locks_held(connid)
        @stats[connid][:locks_held].each do |_, lock|
          lock[:count] += 1
        end
      end

      def add_new_locks_held(connid, payload)
        locked_table = payload[:sql].match(/^UPDATE\s+"?([\w.]+)"?/i).try(:[], 1)

        return unless locked_table.present?

        bind = payload[:binds].find { |b| b[0].name == 'id' }
        return unless bind.present?

        tuple = [locked_table, bind[1]]

        # We only want tuples that were not created in this transaction
        existing_ids = @stats[connid][:existing_ids][tuple[0]]
        return unless existing_ids.present? && existing_ids.include?(tuple[1])

        # We've done two UPDATEs to the same row in this transaction
        return if @stats[connid][:locks_held][tuple].present?

        @stats[connid][:locks_held][tuple] = {}
        @stats[connid][:locks_held][tuple][:sql]   = payload[:sql]
        @stats[connid][:locks_held][tuple][:count] = 0
        @stats[connid][:locks_held][tuple][:started_at] = Time.now
      end

      def handle_begin(connid)
        @stats[connid] = {}
        @stats[connid][:locks_held] = {}
        @stats[connid][:existing_ids] = {}

        ActiveRecord::Base.connection.tables.each do |table|
          next if table == 'schema_migrations'
          @stats[connid][:existing_ids][table] = ActiveRecord::Base.connection.select_values("SELECT id FROM #{table}", 'DBLINT').map(&:to_i)
        end
      end

      def handle_commit(connid)
        @stats[connid][:locks_held].each do |table, details|
          next if details[:count] < 10

          main_app_caller = caller.find { |f| f.start_with?(Rails.root.to_s) }
          main_app_caller.slice!(Rails.root.to_s + '/')
          main_app_dir    = main_app_caller[/^\w+/]
          next if %w(spec test).include?(main_app_dir)

          error_msg = format("Lock on %s held for %d statements (%0.2f ms) by '%s', transaction started by %s",
                             table.inspect, details[:count], Time.now - details[:started_at], details[:sql],
                             main_app_caller)

          if details[:count] > 15
            # We need an explicit begin here since we're interrupting the transaction flow
            ActiveRecord::Base.connection.execute('BEGIN')
            fail Error, error_msg
          else
            puts format('Warning: %s', error_msg)
          end
        end
      end
    end
  end
end
