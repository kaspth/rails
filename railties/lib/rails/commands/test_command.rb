# frozen_string_literal: true

require "rails/command"
require "rails/test_unit/runner"
require "rails/test_unit/reporter"

class Rails::Commands::TestCommand < ActiveCommand::Base # :nodoc:
  help :usage

  def perform
    $LOAD_PATH << Rails::Command.root.join("test").to_s

    Rails::TestUnit::Runner.parse_options(arguments)
    Rails::TestUnit::Runner.run(arguments)
  end
end
