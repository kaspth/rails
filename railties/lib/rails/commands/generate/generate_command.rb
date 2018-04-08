# frozen_string_literal: true

require "rails/generators"

class Rails::Commands::GenerateCommand < ActiveCommand::Base # :nodoc:
  help do
    Rails::Generators.help self.class.command_name
  end

  argument :generator

  before_command :load_generators
  before_command { run :help unless generator }

  def perform
    ARGV.shift

    Rails::Generators.invoke generator, args, behavior: :invoke, destination_root: ActiveCommand.root
  end
end
