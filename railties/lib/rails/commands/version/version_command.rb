# frozen_string_literal: true

class Rails::Commands::VersionCommand < ActiveCommand::Base # :nodoc:
  def perform
    run :application, version: true
  end
end
