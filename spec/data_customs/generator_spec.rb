# frozen_string_literal: true

RSpec.describe "Data migration generator" do
  it "creates a data migration at the right place with the right contents" do
    app_dir = dummy_app_root
    migrations_dir = File.join(app_dir, "db/data_migrations")
    migration_path = File.join(migrations_dir, "foo_bar.rb")
    FileUtils.rm_f(migration_path)
    FileUtils.mkdir_p(migrations_dir)

    stdout, stderr, status = run_command("bundle exec rails generate data_migration foo_bar", chdir: app_dir)

    expect(status.success?).to be(true), -> { "stdout:\n#{stdout}\nstderr:\n#{stderr}" }
    contents = File.read(migration_path)
    expect(contents).to include("class FooBar < DataCustoms::Migration")
    expect(contents).to include("def up")
    expect(contents).to include("def verify!")
  end
end
