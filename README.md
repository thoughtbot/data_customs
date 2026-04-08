# 🛃 Data Customs

> [!WARNING]
> This project is in early development. The API may change before reaching
> version 1.0.0.

A simple gem to help you perform data migrations in your Rails app. The premise
is simple: bundle the migration code along with a verification test to assert
that the migration achieves the desired effect. If either the migration or the
verification step fails, the entire migration is rolled back.

> Can't I just test my rake task or migration script?

Great question. Yes, you should test your migration code (including the Data
Customs migrations). The problem is that **production data is always different
from your test data**, and **in unexpected ways**. This means that even if your
tests pass, the migration might still fail when run in production.

Data Customs provides a safety net by ensuring that if the migration doesn't do
what you expect it to do, the changes are rolled back. This way, you can
investigate the issue and fix it without leaving your data in a half-migrated
(or bad!) state.

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add data_customs
```

If bundler is not being used to manage dependencies, install the gem by
executing:

```bash
gem install data_customs
```

## Usage

### Generating a data migration

You can create a new data migration by running:

```bash
rails generate data_migration MigrationName
```

That will create a file at `db/data_migrations/migration_name.rb`.

### Writing a data migration

After generating a migration, implement the `up` method with the code that
performs the data migration, and the `verify!` method with the code that
asserts that the migration was successful.

```ruby
class AddDefaultUsername < DataCustoms::Migration
  def up
    User.where.missing(:username).update_all(username: "guest")
  end

  def verify!
    if User.exists?(username: nil)
      raise "Some users still have no usernames!"
    end
  end
end

AddDefaultUsername.run # runs the migration and rolls back if necessary
```

Use any exception to indicate failure in the `verify!` method.

> [!TIP]
> Include modules like `RSpec::Matchers` or `Minitest::Assertions` in your
> migration class to use your favorite assertions and matchers inside `verify!`.

If you need to pass arguments to the data migration, you can use an initializer
and `run` will forward any arguments to it.

```ruby
class AddDefaultUsername < DataCustoms::Migration
  def initialize(default_username "guest")
    @default_username = default_username
  end

  def up
    User.where.missing(:username).update_all(username: @default_username)
  end

  def verify!
    if User.exists?(username: nil)
      raise "Some users still have no usernames!"
    end
  end
end

AddDefaultUsername.run("anonymous")
```

#### Dealing with large datasets

By default, the migration code runs inside a transaction. For large datasets,
this [blocks the database][blocking] for the duration of the migration. To
avoid this, use `atomic false` to opt out of the transaction.

Non-atomic migrations require a `down` method that reverts the changes made by
`up`. Since there is no transaction to roll back, `down` is your rollback
strategy: if `up` or `verify!` fails, `down` is called automatically. It should
be idempotent, as the gem does not track which records were changed.

```ruby
class BackfillDefaultUsername < DataCustoms::Migration
  atomic false

  def up
    batch(User.where(username: nil)) do |rel|
      rel.update_all(username: "guest")
    end
  end

  def verify!
    raise "Failed" if User.exists?(username: nil)
  end

  def down
    User.where(username: "guest").update_all(username: nil)
  end
end
```

The `batch` and `find_each` helpers process records using
[`in_batches`][in_batches], with a short pause between each batch so other
queries can run in between. Use `find_each` when you need access to individual
records instead of relations.

Both methods accept `batch_size` and `throttle_seconds` options:

```ruby
batch(records, batch_size: 500, throttle_seconds: 0.1) do |relation|
  # ...
end

find_each(records, batch_size: 500, throttle_seconds: 0.1) do |record|
  # ...
end
```

#### Reporting progress

For long-running migrations, you can use `progress.report` to display a progress
bar:

```ruby
class BackfillUsernames < DataCustoms::Migration
  def up
    scope = User.where(username: nil)
    total = scope.count
    processed = 0

    find_each(scope) do |user|
      user.update!(username: "guest_#{user.id}")
      processed += 1
      progress.report(processed.to_f / total * 100)
    end
  end

  def verify!
    raise "Some users still have no usernames!" if User.exists?(username: nil)
  end
end
```

```
🛃 Progress: ██████████░░░░░░░░░░ 50%
🛃 Progress: ████████████████████ 100% (5s elapsed)
🛃 Data migration ran successfully!
```

It accepts a percentage (0–100) and throttles output, so it's safe to call on
every iteration. At 100%, it shows the total elapsed time.

Use `progress eta: true` at the class level to show estimated time remaining:

```ruby
class BackfillUsernames < DataCustoms::Migration
  progress eta: true

  def up
    scope = User.where(username: nil)
    total = scope.count
    processed = 0

    find_each(scope) do |user|
      user.update!(username: "guest_#{user.id}")
      processed += 1
      progress.report(processed.to_f / total * 100)
    end
  end

  # ...
end
```

```
🛃 Progress: ██████████░░░░░░░░░░ 50% (2m 30s left)
```

### Running a data migration in the command line

These migrations don't run automatically. You need to invoke them manually.
Since they might take some time, you can choose the best time to run them.

If you want to run a data migration from the command line, you can use the
`data_customs:run` task. It accepts the migration class name (either in
PascalCase or snake_case) as an argument:

```bash
rails data_customs:run NAME=AddDefaultUsername
# or
rake data_customs:run NAME=add_default_username
```

If you need to pass arguments to the migration, you can do so by passing them as
additional arguments to the task:

```bash
rails data_customs:run NAME=AddDefaultUsername ARGS="anonymous"
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at
<https://github.com/thoughtbot/data_customs>.

This project is intended to be a safe, welcoming space for collaboration, and
contributors are expected to adhere to the [code of
conduct](https://github.com/thoughtbot/data_customs/blob/main/CODE_OF_CONDUCT.md).

## License

Open source templates are Copyright (c) thoughtbot, inc. It contains free
software that may be redistributed under the terms specified in the
[LICENSE](https://github.com/thoughtbot/data_customs/blob/main/LICENSE.txt)
file.

## Code of Conduct

Everyone interacting in the DataCustoms project's codebases, issue trackers,
chat rooms and mailing lists is expected to follow the [code of
conduct](https://github.com/thoughtbot/data_customs/blob/main/CODE_OF_CONDUCT.md).

<!-- START /templates/footer.md -->

## About thoughtbot

![thoughtbot](https://thoughtbot.com/thoughtbot-logo-for-readmes.svg)

This repo is maintained and funded by thoughtbot, inc. The names and logos for
thoughtbot are trademarks of thoughtbot, inc.

We love open source software! See [our other projects][community]. We are
[available for hire][hire].

[community]: https://thoughtbot.com/community?utm_source=github&utm_medium=readme&utm_campaign=data_customs
[hire]: https://thoughtbot.com/hire-us?utm_source=github&utm_medium=readme&utm_campaign=data_customs

<!-- END /templates/footer.md -->

[blocking]: https://github.com/ankane/strong_migrations?tab=readme-ov-file#backfilling-data
[in_batches]: https://api.rubyonrails.org/classes/ActiveRecord/Batches.html#method-i-in_batches
