require "rails/command/helpers/editor"

class Rails::Commands::Encrypted::EditCommand < ActiveCommand::Base
  include Helpers::Editor

  before_command { @encrypted = Rails.application.encrypted(file_path, key_path: key) }
  before_command { throw :halt unless ensure_editor_available(command: "bin/rails encrypted:edit") }

  before_command { ensure_encryption_key_has_been_added(key) }, if: -> { @encrypted.key.nil? }
  before_command { ensure_encrypted_file_has_been_added(file_path, key) }

  def perform
    catch_editing_exceptions do
      change_encrypted_file_in_system_editor(file_path, key)
    end

    say "File encrypted and saved."
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    say "Couldn't decrypt #{file_path}. Perhaps you passed the wrong key?"
  end

  private
    def ensure_encryption_key_has_been_added(key_path)
      encryption_key_file_generator.add_key_file(key_path)
      encryption_key_file_generator.ignore_key_file(key_path)
    end

    def ensure_encrypted_file_has_been_added(file_path, key_path)
      encrypted_file_generator.add_encrypted_file_silently(file_path, key_path)
    end

    def change_encrypted_file_in_system_editor(file_path, key_path)
      Rails.application.encrypted(file_path, key_path: key_path).change do |tmp_path|
        system("#{ENV["EDITOR"]} #{tmp_path}")
      end
    end


    def encryption_key_file_generator
      require "rails/generators"
      require "rails/generators/rails/encryption_key_file/encryption_key_file_generator"

      Rails::Generators::EncryptionKeyFileGenerator.new
    end

    def encrypted_file_generator
      require "rails/generators"
      require "rails/generators/rails/encrypted_file/encrypted_file_generator"

      Rails::Generators::EncryptedFileGenerator.new
    end
end
