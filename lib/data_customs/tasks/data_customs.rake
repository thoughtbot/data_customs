namespace :data_customs do
  desc 'Run a single data migration from db/data_migrations'
  task run: :environment do
    name = ENV['NAME']
    abort '❌ Missing migration name (e.g. `rake data_customs:run NAME=fix_users`)' unless name

    path = Rails.root.join('db', 'data_migrations', "#{name.underscore}.rb")
    abort "❌ Migration not found: #{path}" unless File.exist?(path)

    require path
    migration_class = name.camelize.constantize
    if args = ENV['ARGS']
      migration_class.run(args.split(','))
    else
      migration_class.run
    end
  end
end
