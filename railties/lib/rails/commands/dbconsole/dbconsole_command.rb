# frozen_string_literal: true

require_relative "dbconsole"
require "rails/command/environment_argument"

class Rails::Commands::DbconsoleCommand < ActiveCommand::Base # :nodoc:
  include EnvironmentArgument

  option :include_password, aliases: "-p", type: :boolean, desc: "Use password from database.yml"
  option :mode, enum: %w( html list line column ), type: :string, desc: "Put the sqlite3 database in the specified mode (html, list, line, column)."
  option :header, type: :boolean
  option :connection, aliases: "-c", type: :string

  before_command :extract_environment_option_from_argument
  before_command { ENV["RAILS_ENV"] = options[:environment] }

  def perform
    Rails::DBConsole.start(options)
  end
end
