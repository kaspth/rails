# frozen_string_literal: true

class Rails::Commands::RunnerCommand < ActiveCommand::Base # :nodoc:
  option :environment, aliases: "-e", type: :string, default: Rails::Command.environment.dup,
    desc: "The environment for the runner to operate under (test/development/production)"

  help do
    super
    puts self.class.desc
  end

  banner do
    "#{super} [<'Some.ruby(code)'> | <filename.rb> | -]"
  end

  argument :code_or_file

  before_command { run :help && exit 1 unless code_or_file }
  before_command { ENV["RAILS_ENV"] = options[:environment] }

  def perform
    Rails.application.load_runner

    ARGV.replace(arguments)

    if code_or_file == "-"
      eval($stdin.read, TOPLEVEL_BINDING, "stdin")
    elsif File.exist?(code_or_file)
      $0 = code_or_file
      Kernel.load code_or_file
    else
      begin
        eval(code_or_file, TOPLEVEL_BINDING, __FILE__, __LINE__)
      rescue SyntaxError, NameError => error
        $stderr.puts "Please specify a valid ruby command or the path of a script to run."
        $stderr.puts "Run '#{self.class.executable} -h' for help."
        $stderr.puts
        $stderr.puts error
        exit 1
      end
    end
  end
end
