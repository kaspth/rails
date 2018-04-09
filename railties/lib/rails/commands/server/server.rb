require "fileutils"
require "optparse"
require "action_dispatch"
require "rails"
require "active_support/deprecation"
require "rails/dev_caching"

module Rails
  class Server < ::Rack::Server
    class Options
      def parse!(args)
        Rails::Commands::ServerCommand.new.send(:server_options)
      end
    end

    def initialize(options = nil)
      @default_options = options || {}
      super(@default_options)
      set_environment
    end

    def app
      @app ||= begin
        app = super
        if app.is_a?(Class)
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            Using `Rails::Application` subclass to start the server is deprecated and will be removed in Rails 6.0.
            Please change `run #{app}` to `run Rails.application` in config.ru.
          MSG
        end
        app.respond_to?(:to_app) ? app.to_app : app
      end
    end

    def opt_parser
      Options.new
    end

    def set_environment
      ENV["RAILS_ENV"] ||= options[:environment]
    end

    def start(after_stop_callback = nil)
      trap(:INT) { exit }
      create_tmp_directories
      setup_dev_caching
      log_to_stdout if options[:log_stdout]

      super()
    ensure
      after_stop_callback.call if after_stop_callback
    end

    def serveable? # :nodoc:
      server
      true
    rescue LoadError, NameError
      false
    end

    def middleware
      Hash.new([])
    end

    def default_options
      super.merge(@default_options)
    end

    def served_url
      "#{options[:SSLEnable] ? 'https' : 'http'}://#{options[:Host]}:#{options[:Port]}" unless use_puma?
    end

    private
      def setup_dev_caching
        if options[:environment] == "development"
          Rails::DevCaching.enable_by_argument(options[:caching])
        end
      end

      def create_tmp_directories
        %w(cache pids sockets).each do |dir_to_make|
          FileUtils.mkdir_p(File.join(Rails.root, "tmp", dir_to_make))
        end
      end

      def log_to_stdout
        wrapped_app # touch the app so the logger is set up

        console = ActiveSupport::Logger.new(STDOUT)
        console.formatter = Rails.logger.formatter
        console.level = Rails.logger.level

        unless ActiveSupport::Logger.logger_outputs_to?(Rails.logger, STDOUT)
          Rails.logger.extend(ActiveSupport::Logger.broadcast(console))
        end
      end

      def restart_command
        "bin/rails server #{ARGV.join(' ')}"
      end

      def use_puma?
        server.to_s == "Rack::Handler::Puma"
      end
  end
end
