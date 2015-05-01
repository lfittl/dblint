module Dblint
  module Checks
    class Base
      def find_main_app_caller(callstack)
        main_app_caller = callstack.find { |f| f.start_with?(Rails.root.to_s) }
        main_app_caller.slice!(Rails.root.to_s + '/')
        main_app_dir    = main_app_caller[/^\w+/]
        return if %w(spec test).include?(main_app_dir)
        main_app_caller
      end
    end
  end
end
