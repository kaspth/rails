# frozen_string_literal: true

require "active_support"

class Rails::Commands::Credentials < ActiveCommand::Collection # :nodoc:
  help do
    say "Usage:\n  #{self.class.banner}"
    say ""
    say read_usage_file
  end

  def show
    say Rails.application.credentials.read.presence || missing_credentials_message
  end

  private
    def missing_credentials_message
      if Rails.application.credentials.key.nil?
        "Missing master key to decrypt credentials. See bin/rails credentials:help"
      else
        "No credentials have been added yet. Use bin/rails credentials:edit to change that."
      end
    end
end
