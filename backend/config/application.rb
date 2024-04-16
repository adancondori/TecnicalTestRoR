require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TecnicalProject
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.autoload_paths += %W(#{config.root}/extras)
    config.autoload_paths += %W(#{config.root}/app/lib)
    config.autoload_paths += %W(#{config.root}/app/models/ckeditor)
    config.autoload_paths += %W(#{config.root}/app/models/directory)
    # Configuración de Middlewares de la aplicación
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins 'localhost:5173', '127.0.0.1:5173'  # Aquí añades los orígenes permitidos
        resource '*',
          headers: :any,
          methods: [:get, :post, :patch, :put, :delete, :options, :head],
          expose: ['Authorization']  # Opcional: headers que quieres exponer
      end
    end
  end
end
