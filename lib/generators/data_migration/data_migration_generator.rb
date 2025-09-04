# frozen_string_literal: true

require "rails/generators"
require "rails/generators/named_base"

module DataMigration
  class DataMigrationGenerator < Rails::Generators::NamedBase
    source_root File.expand_path("templates", __dir__)

    def create_data_migration_file
      template "data_migration.rb.tt", File.join("db/data_migrations", "#{file_name.underscore}.rb")
    end
  end
end
