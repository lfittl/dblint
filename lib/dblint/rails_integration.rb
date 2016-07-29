require 'active_support/notifications'

module Dblint
  class RailsIntegration
    CHECKS = [
      Dblint::Checks::LongHeldLock,
      Dblint::Checks::MissingIndex
    ].freeze

    def check_instance_for_connection(connid, klass)
      @checks ||= {}
      @checks[connid] ||= {}
      @checks[connid][klass] ||= klass.new
    end

    def start(name, id, payload)
      return if %w(CACHE DBLINT SCHEMA).include?(payload[:name])

      CHECKS.each do |check_klass|
        check = check_instance_for_connection(payload[:connection_id], check_klass)
        check.statement_started(name, id, payload)
      end
    end

    def finish(name, id, payload)
      return if %w(CACHE DBLINT SCHEMA).include?(payload[:name])

      CHECKS.each do |check_klass|
        check = check_instance_for_connection(payload[:connection_id], check_klass)
        check.statement_finished(name, id, payload_from_version(ActiveRecord::VERSION::MAJOR, payload))
      end
    end

    private

    def payload_from_version(version, payload)
      return payload if version == 4

      compatible_binds = payload[:binds].map { |bind| [bind, bind.value] }
      payload.merge(binds: compatible_binds)
    end
  end

  ActiveSupport::Notifications.subscribe('sql.active_record', RailsIntegration.new)
end
