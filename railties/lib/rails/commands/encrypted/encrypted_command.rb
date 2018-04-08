# frozen_string_literal: true

require "pathname"
require "active_support"

class Rails::Commands::EncryptedCommand < ActiveCommand::Collection # :nodoc:
  help do
    say "Usage:\n  #{self.class.banner}"
    say ""
  end

  option :key, aliases: "-k", type: :string, default: "config/master.key",
    desc: "The Rails.root relative path to the encryption key"

  argument :file_path

  def show
    encrypted = Rails.application.encrypted(file_path, key_path: key)

    say encrypted.read.presence || missing_encrypted_message(key: encrypted.key, key_path: key, file_path: file_path)
  end

  private
    def missing_encrypted_message(key:, key_path:, file_path:)
      if key.nil?
        "Missing '#{key_path}' to decrypt data. See bin/rails encrypted:help"
      else
        "File '#{file_path}' does not exist. Use bin/rails encrypted:edit #{file_path} to change that."
      end
    end
end
