module Dblint
  module Checks
    class MissingIndex < Base
      class Error < StandardError; end

      def statement_started(_name, _id, payload)
        return if payload[:sql].include?(';')
        return unless payload[:sql].starts_with?('SELECT')

        ActiveRecord::Base.connection.execute 'SET enable_seqscan = off', 'DBLINT'
        plan = explain(payload)
        raise_on_seqscan(plan[0]['Plan'], payload)
        ActiveRecord::Base.connection.execute 'SET enable_seqscan = on', 'DBLINT'
      end

      def statement_finished(_name, _id, _payload)
        # Ignored
      end

      private

      def explain(payload)
        plan = ActiveRecord::Base.connection.select_value(format('EXPLAIN (FORMAT JSON) %s', payload[:sql]),
                                                          'DBLINT', payload[:binds])
        JSON.parse(plan)
      end

      def raise_on_seqscan(plan, payload)
        if plan['Node Type'] == 'Seq Scan' && plan['Filter'].present?
          main_app_caller = find_main_app_caller(caller)
          return unless main_app_caller.present?

          return if ignored?(main_app_caller)

          error_msg = format("Missing index on %s for '%s' in '%s', called by %s",
                             plan['Relation Name'], plan['Filter'], payload[:sql], main_app_caller)
          fail Error, error_msg
        end

        (plan['Plans'] || []).each do |subplan|
          raise_on_seqscan(subplan, payload)
        end
      end
    end
  end
end
