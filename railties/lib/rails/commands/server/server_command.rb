# frozen_string_literal: true

require "fileutils"
require "optparse"
require "action_dispatch"
require "rails"
require "active_support/deprecation"
require "active_support/core_ext/string/filters"

class Rails::Commands::ServerCommand < ActiveCommand::Base # :nodoc:
  # Hard-coding a bunch of handlers here as we don't have a public way of
  # querying them from the Rack::Handler registry.
  RACK_SERVERS = %w(cgi fastcgi webrick lsws scgi thin puma unicorn)

  DEFAULT_PORT = 3000
  DEFAULT_PID_PATH = "tmp/pids/server.pid".freeze

  argument :using, optional: true

  option :port,         aliases: "-p", default: 3000,  banner: :port,  desc: "Runs Rails on the specified port - defaults to 3000."
  option :binding,      aliases: "-b",                 banner: :IP,    desc: "Binds Rails to the specified IP - defaults to 'localhost' in development and '0.0.0.0' in other environments'.",
  option :config,       aliases: "-c",                 banner: :file,  default: "config.ru", desc: "Uses a custom rackup configuration."
  option :environment,  aliases: "-e",                 banner: :name,  desc: "Specifies the environment to run this server under (development/test/production)."
  option :using,        aliases: "-u",                 banner: :name,  desc: "Specifies the Rack server used to run the application (thin/puma/webrick)."
  option :pid,          aliases: "-P",                 default: DEFAULT_PID_PATH, desc: "Specifies the PID file."
  option :daemon,       aliases: "-d", default: false, desc: "Runs server as a Daemon."
  option "dev-caching", aliases: "-C", default: nil,   desc: "Specifies whether to perform caching in development."
  option :restart,                     default: nil,   hide: true
  option :early_hints,                 default: nil,   desc: "Enables HTTP/2 early hints."

  before_command do
    @using = deprecated_positional_rack_server(using) || options[:using]
    @log_stdout = options[:daemon].blank? && options.fetch(:environment, Rails.env) == "development"
  end

  def perform
    set_application_directory!
    prepare_restart

    Rails::Server.new(server_options).tap do |server|
      # Require application after server sets environment to propagate
      # the --environment option.
      require APP_PATH
      Dir.chdir(Rails.application.root)

      if server.serveable?
        print_boot_information(server.server, server.served_url)
        after_stop_callback = -> { say "Exiting" unless options[:daemon] }
        server.start(after_stop_callback)
      else
        say rack_server_suggestion(using)
      end
    end
  end

  private
    def server_options
      {
        user_supplied_options: user_supplied_options,
        server:                using,
        log_stdout:            @log_stdout,
        Port:                  port,
        Host:                  host,
        DoNotReverseLookup:    true,
        config:                options[:config],
        environment:           environment,
        daemonize:             options[:daemon],
        pid:                   pid,
        caching:               options["dev-caching"],
        restart_cmd:           restart_command,
        early_hints:           early_hints
      }
    end

    def user_supplied_options
      @user_supplied_options ||= begin
        # Convert incoming options array to a hash of flags
        #   ["-p3001", "-C", "--binding", "127.0.0.1"] # => {"-p"=>true, "-C"=>true, "--binding"=>true}
        user_flag = {}
        @original_options.each do |command|
          if command.to_s.start_with?("--")
            option = command.split("=")[0]
            user_flag[option] = true
          elsif command =~ /\A(-.)/
            user_flag[Regexp.last_match[0]] = true
          end
        end

        # Collect all options that the user has explicitly defined so we can
        # differentiate them from defaults
        user_supplied_options = []
        self.class.class_options.select do |key, option|
          if option.aliases.any? { |name| user_flag[name] } || user_flag["--#{option.name}"]
            name = option.name.to_sym
            case name
            when :port
              name = :Port
            when :binding
              name = :Host
            when :"dev-caching"
              name = :caching
            when :daemonize
              name = :daemon
            end
            user_supplied_options << name
          end
        end
        user_supplied_options << :Host if ENV["HOST"]
        user_supplied_options << :Port if ENV["PORT"]
        user_supplied_options.uniq
      end
    end

    def port
      options[:port] || ENV.fetch("PORT", DEFAULT_PORT).to_i
    end

    def host
      if options[:binding]
        options[:binding]
      else
        default_host = environment == "development" ? "localhost" : "0.0.0.0"
        ENV.fetch("HOST", default_host)
      end
    end

    def environment
      options[:environment] || Rails::Command.environment
    end

    def restart_command
      "bin/rails server #{using} #{@original_options.join(" ")} --restart"
    end

    def early_hints
      options[:early_hints]
    end

    def pid
      File.expand_path(options[:pid])
    end

    def self.banner(*)
      "rails server [thin/puma/webrick] [options]"
    end

    def prepare_restart
      FileUtils.rm_f(options[:pid]) if options[:restart]
    end

    def deprecated_positional_rack_server(value)
      if value
        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          Passing the Rack server name as a regular argument is deprecated
          and will be removed in the next Rails version. Please, use the -u
          option instead.
        MSG
        value
      end
    end

    def rack_server_suggestion(server)
      if server.in?(RACK_SERVERS)
        <<~MSG
          Could not load server "#{server}". Maybe you need to the add it to the Gemfile?

            gem "#{server}"

          Run `rails server --help` for more options.
        MSG
      else
        suggestions = Rails::Command::Spellchecker.suggest(server, from: RACK_SERVERS)

        <<~MSG
          Could not find server "#{server}". Maybe you meant #{suggestions.inspect}?
          Run `rails server --help` for more options.
        MSG
      end
    end

    def print_boot_information(server, url)
      say <<~MSG
        => Booting #{ActiveSupport::Inflector.demodulize(server)}
        => Rails #{Rails.version} application starting in #{Rails.env} #{url}
        => Run `rails server --help` for more startup options
      MSG
    end
end
