require 'active_support/core_ext/string/inflections'

module Dblint
  module Checks
    class Base
      def check_name
        self.class.name.demodulize
      end

      def find_main_app_caller(callstack)
        main_app_caller = callstack.find { |f| f.start_with?(Rails.root.to_s) && !f.include?('/vendor/bundle') }
        main_app_caller.slice!(Rails.root.to_s + '/')

        main_app_dir = main_app_caller[/^\w+/]
        return if %w(spec test).include?(main_app_dir)

        main_app_caller
      end

      def ignored?(main_app_caller)
        return false unless config && config['IgnoreList']

        ignores = config['IgnoreList'][check_name]
        ignores.present? && ignores.include?(main_app_caller)
      end

      def config
        @config ||= begin
          config_file = Rails.root.join('.dblint.yml')
          YAML.load(File.read(config_file)) if File.exist?(config_file)
        end
      end
    end
  end
end
