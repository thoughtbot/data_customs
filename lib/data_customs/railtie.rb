require "rails/railtie"

module DataCustoms
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.expand_path("tasks/data_customs.rake", __dir__)
    end

    generators do
      require "generators/data_migration/data_migration_generator"
    end
  end
end
