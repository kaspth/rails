require 'active_support/core_ext/string/strip'

module ActionController
  # Handles implicit rendering for a controller action when it did not
  # explicitly indicate a response via e.g. +render+, +respond_to+,
  # +redirect+ or +head+.
  #
  # For API controllers, the implicit render always renders
  # "204 No Content" and does not account for any templates.
  #
  # For other controllers, the implicit render still falls back to rendering
  # "204 No Content", though not before exhausting 3 other options first.
  #
  # First, if a template exists for the controller action, it is rendered.
  # This template lookup takes into account the action name, format, locales,
  # handlers, variants etc.
  #
  # Second, if any templates exist for the controller action in any other
  # format, variant, etc. an <tt>ActionController::UnknownFormat</tt> is raised
  # because the available templates is assumed exhaustive. E.g. writing only an
  # HTML template means only that format is known.
  #
  # Third and last, if the current request is a real "interactive" browser request,
  # <tt>ActionView::MissingTemplate</tt> is raised to display a helpful error
  # message.
  module ImplicitRender

    # :stopdoc:
    include BasicImplicitRender

    def default_render(*args)
      if template_exists?(action_name.to_s, _prefixes, variants: request.variant)
        return render(*args)
      elsif any_templates?(action_name.to_s, _prefixes)
        raise ActionController::UnknownFormat, <<-eow.strip_heredoc
          #{self.class.name}\##{action_name} did not have any templates for the
          formats #{request.formats} or variant #{request.variant}.
        eow
      elsif interactive_browser_request?
        raise ActionView::MissingTemplate.new(<<-eow.strip_heredoc, action_name.to_s)
          No template found for #{self.class.name}\##{action_name}.
        eow
      else
        logger.info "No template found for #{self.class.name}\##{action_name}, rendering head :no_content" if logger
        super
      end
    end

    def method_for_action(action_name)
      super || if template_exists?(action_name.to_s, _prefixes)
        "default_render"
      end
    end

    private

      def interactive_browser_request?
        request.format == Mime[:html] && !request.xhr?
      end
  end
end
