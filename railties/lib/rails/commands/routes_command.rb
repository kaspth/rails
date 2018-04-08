# frozen_string_literal: true

require "rails/command"

class Rails::Commands::RoutesCommand < ActiveCommand::Base # :nodoc:
  option :controller, aliases: "-c", desc: "Filter by a specific controller, e.g. PostsController or Admin::PostsController."
  option :grep, aliases: "-g", desc: "Grep routes by a specific pattern."
  option :expanded, type: :boolean, aliases: "-E", desc: "Print routes expanded vertically with parts explained."

  def perform
    require "action_dispatch/routing/inspector"

    puts inspector.format(formatter, routes_filter)
  end

  private
    def inspector
      ActionDispatch::Routing::RoutesInspector.new(Rails.application.routes.routes)
    end

    def formatter
      if expanded
        ActionDispatch::Routing::ConsoleFormatter::Expanded.new
      else
        ActionDispatch::Routing::ConsoleFormatter::Sheet.new
      end
    end

    def routes_filter
      options.slice(:controller, :grep)
    end
  end
end
