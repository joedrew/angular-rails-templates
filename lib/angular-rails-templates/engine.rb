require 'tilt'

module AngularRailsTemplates
  class Engine < ::Rails::Engine
    config.angular_templates = ActiveSupport::OrderedOptions.new
    config.angular_templates.module_name    = 'templates'
    config.angular_templates.ignore_prefix  = 'templates/'
    config.angular_templates.markups        = []
    config.angular_templates.htmlcompressor = false

    # try loading common markups
    %w(erb haml liquid md radius slim str textile wiki).
    each do |ext|
      begin
        silence_warnings do
          config.angular_templates.markups << ext if Tilt[ext]
        end
      rescue LoadError
        # They don't have the required library required. Oh well.
      end
    end


    config.before_initialize do |app|
      if app.config.assets
        require 'sprockets'
        require 'sprockets/engines' # load sprockets for Rails 3

        if app.config.angular_templates.htmlcompressor
          require 'htmlcompressor/compressor'
          unless app.config.angular_templates.htmlcompressor.is_a? Hash
            app.config.angular_templates.htmlcompressor = {remove_intertag_spaces: true}
          end
        end

        # These engines render markup as HTML
        app.config.angular_templates.markups.each do |ext|
          custom_engine = Class.new(Tilt[ext]) do
            # Processed haml/slim templates have a mime-type of text/html.
            # If sprockets sees a `foo.html.haml` it will process the haml
            # and stop, because the haml output is html. Our html engine won't get run.
            def self.default_mime_type
              nil
            end

            # Add helpers into the Scopes of the supported templates
            def render(scope=Object.new, locals={}, &block)
              scope.class_eval do
                include ApplicationHelper
                include ActionView::Helpers
                include Rails.application.routes.url_helpers
              end
              super scope, locals || {}, &block
            end
          end

          Sprockets.register_engine ".#{ext}", custom_engine
        end

        # This engine wraps the HTML into JS
        Sprockets.register_engine '.html', AngularRailsTemplates::Template
      end

      # Sprockets Cache Busting
      # If ART's version or settings change, expire and recompile all assets
      app.config.assets.version = [
        app.config.assets.version,
        'ART',
        Digest::MD5.hexdigest("#{VERSION}-#{app.config.angular_templates}")
      ].join '-'
    end

    # config.after_initialize do |app|
    #   app.assets.context_class.class_eval do
    #     include ApplicationHelper
    #     include ActionView::Helpers
    #     include Rails.application.routes.url_helpers
    #   end
    # end
  end
end
