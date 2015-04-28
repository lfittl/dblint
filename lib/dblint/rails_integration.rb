require 'active_support/notifications'

module Dblint
  class RailsIntegration
    CHECKS = [
      Dblint::Checks::LongHeldLock
    ]

    def start(name, id, payload)
      CHECKS.each do |check|
        check.statement_started(name, id, payload)
      end
    end

    def finish(name, id, payload)
      CHECKS.each do |check|
        check.statement_finished(name, id, payload)
      end
    end
  end

  ActiveSupport::Notifications.subscribe('sql.active_record', RailsIntegration.new)
end
