# frozen_string_literal: true

require "active_support"
require "active_support/dependencies/autoload"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/object/blank"

require "thor"

module Rails
  module Command
    extend ActiveSupport::Autoload

    autoload :Spellchecker
    autoload :Behavior
    autoload :Base

    include Behavior

    HELP_MAPPINGS = %w(-h -? --help)

    class << self
      def hidden_commands # :nodoc:
        @hidden_commands ||= []
      end

      def environment # :nodoc:
        ENV["RAILS_ENV"].presence || ENV["RACK_ENV"].presence || "development"
      end

      class Invocation
        def initialize(lookup)
          @lookup  = lookup
          @nesting = lookup.split(":")
        end

        def namespace
          @lookup
        end

        def command
          case command = @nesting.last.presence
          when "-v", "--version"
            "version"
          when nil, *HELP_MAPPINGS
            "help"
          else
            command
          end
        end

        def lookups
          [ @lookup ]
        end

        def lookup_paths
          lookups.map { |l| l.tr(":", "/") } + [ "#{command}/#{command}" ]
        end

        # def command
        #   Rails::Command.send(:lookup_paths).dig(@nesting)
        # end
        #
        # def perform
        #   command.send(command_name)
        # end
      end

      # Receives a namespace, arguments and the behavior to invoke the command.
      def invoke(full_namespace, args = [], **config)
        require "byebug"; byebug

        invocation = Invocation.new(full_namespace.to_s)

        command = find_command(invocation)
        if command && command.all_commands[invocation.command]
          command.perform(invocation.command, args, config)
        else
          find_command("rake").perform(full_namespace, args, config)
        end
      end

      def find_command(invocation)
        lookup(invocation.lookup_paths)

        indexed = subclasses.index_by(&:namespace)
        huh = (invocation.lookups & indexed.keys).first
        indexed[huh]
      end

      # Returns the root of the Rails engine or app running the command.
      def root
        if defined?(ENGINE_ROOT)
          Pathname.new(ENGINE_ROOT)
        elsif defined?(APP_PATH)
          Pathname.new(File.expand_path("../..", APP_PATH))
        end
      end

      def print_commands # :nodoc:
        sorted_groups.each { |b, n| print_list(b, n) }
      end

      def sorted_groups # :nodoc:
        lookup!

        groups = (subclasses - hidden_commands).group_by { |c| c.namespace.split(":").first }
        groups.transform_values! { |commands| commands.flat_map(&:printing_commands).sort }

        rails = groups.delete("rails")
        [[ "rails", rails ]] + groups.sort.to_a
      end

      private
        def command_type # :doc:
          @command_type ||= "command"
        end

        def lookup_paths # :doc:
          @lookup_paths ||= %w( rails/commands commands )
        end

        def file_lookup_paths # :doc:
          @file_lookup_paths ||= [ "{#{lookup_paths.join(',')}}", "**", "*_command.rb" ]
        end
    end
  end
end
