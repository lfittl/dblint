require 'active_support/notifications'

module Dblint
  class LongHeldLock < StandardError; end

  class RailsIntegration
    def start(name, id, payload)
      # not used
    end

    def add_new_locks_held(connid, payload)
      locked_table = payload[:sql].match(/^UPDATE\s+"?([\w.]+)"?/i).try(:[], 1)

      return unless locked_table.present?

      bind = payload[:binds].find { |b| b[0].name == 'id' }
      return unless bind.present?

      tuple = [locked_table, bind[1]]

      # We've done two UPDATEs to the same row in this transaction
      return if @stats[connid][:locks_held][tuple].present?

      @stats[connid][:locks_held][tuple] = {}
      @stats[connid][:locks_held][tuple][:sql]   = payload[:sql]
      @stats[connid][:locks_held][tuple][:count] = 0
      @stats[connid][:locks_held][tuple][:started_at] = Time.now
    end

    def increment_locks_held(connid)
      @stats[connid][:locks_held].each do |_, lock|
        lock[:count] += 1
      end
    end

    def finish(name, id, payload)
      return if ['CACHE', 'DBLINT', 'SCHEMA'].include?(payload[:name])

      @stats ||= {}

      connid = payload[:connection_id]

      if payload[:sql] == 'BEGIN'
        @stats[connid] = {}
        @stats[connid][:locks_held] = {}
        @stats[connid][:existing_ids] = {}

        ActiveRecord::Base.connection.tables.each do |table|
          next if table == 'schema_migrations'
          @stats[connid][:existing_ids][table] = ActiveRecord::Base.connection.select_values("SELECT id FROM #{table}", 'DBLINT')
        end

      elsif payload[:sql] == 'COMMIT'
        @stats[connid][:locks_held].each do |table, details|
          next if details[:count] < 10

          main_app_caller = caller.find { |f| f.start_with?(Rails.root.to_s) }
          main_app_caller.slice!(Rails.root.to_s + '/')
          main_app_dir    = main_app_caller[/^\w+/]

          next if ['spec', 'test'].include?(main_app_dir)

          error_msg = format("Lock on %s held for %d statements (%0.2f ms) by '%s', transaction started by %s",
                             table.inspect, details[:count], Time.now - details[:started_at], details[:sql],
                             main_app_caller)

          if details[:count] > 15
            fail LongHeldLock.new(error_msg)
          else
            puts format('Warning: %s', error_msg)
          end
        end
      elsif payload[:sql] == 'ROLLBACK'
        # do nothing
      elsif @stats[connid].present?
        increment_locks_held(connid)
        add_new_locks_held(connid, payload)
      end
    end

    ActiveSupport::Notifications.subscribe("sql.active_record", new)
  end
end
