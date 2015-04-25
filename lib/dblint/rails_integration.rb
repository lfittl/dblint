require 'active_support/notifications'

module Dblint
  class RailsIntegration # :nodoc:
    LOCK_SQL = """
    SELECT relname
      FROM pg_locks pl
      JOIN pg_class pc ON (pc.oid = pl.relation)
     WHERE pid = pg_backend_pid()
       AND relkind NOT IN ('i', 's')
       AND mode NOT IN ('AccessShareLock', 'RowShareLock')
    """

    def start(name, id, payload)
      # not used
    end

    def refresh_locks_held(connid, sql)
      tables = []

      ActiveRecord::Base.connection.select_all(LOCK_SQL, 'DBLINT').each do |lock|
        tables << lock['relname']
      end

      tables.uniq.each do |table|
        if @stats[connid][:locks_held][table].nil?
          @stats[connid][:locks_held][table] ||= {}
          @stats[connid][:locks_held][table][:sql]   = sql
          @stats[connid][:locks_held][table][:count] = 0
          @stats[connid][:locks_held][table][:started_at] = Time.now
        else
          @stats[connid][:locks_held][table][:count] += 1
        end
      end
    end

    def finish(name, id, payload)
      return if ['CACHE', 'DBLINT', 'SCHEMA'].include?(payload[:name])

      @stats ||= {}

      connid = payload[:connection_id]

      if payload[:sql] == 'BEGIN'
        @stats[connid] = {}
        @stats[connid][:started_at] = Time.now
        @stats[connid][:locks_held] = {}
      elsif payload[:sql] == 'COMMIT'
        #tx_duration = Time.now - @stats[connid][:started_at]
        #puts tx_duration.inspect

        @stats[connid][:locks_held].each do |table, details|
          next if details[:count] < 10

          puts format("Warning: Locks on %s held for %d statements (%0.2f ms) by '%s'",
                      table, details[:count], Time.now - details[:started_at], details[:sql])
        end
      else
        refresh_locks_held(connid, payload[:sql])
      end
    end

    ActiveSupport::Notifications.subscribe("sql.active_record", new)
  end
end
