## [Unreleased]

- Add `atomic false` mode for non-atomic migrations that don't hold a transaction open

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

  - Requires a `down` method (raises `ArgumentError` if missing)
  - Automatically calls `down` if `up` or `verify!` fails
  - If `down` itself fails, warns and re-raises the original error
- Disable throttling by default in atomic mode (`batch`/`find_each` only throttle in non-atomic mode)

## [0.2.0] - 2026-03-04

- Add `progress.report` for tracking migration progress with a visual bar that updates in place on TTY terminals
- Add `progress eta: true` class-level macro to enable ETA display without passing it on every `report` call

```ruby
class MyMigration < DataCustoms::Migration
  progress eta: true

  def up
    users = User.where(active: true)
    total = users.count
    users.find_each.with_index(1) do |user, i|
      user.update!(name: user.name.strip)
      progress.report(i * 100 / total)
    end
    progress.report(100)
  end
end

MyMigration.run
# 🛃 Progress: ██████████░░░░░░░░░░ 50% (2m 30s left)
```

- Fix transaction to wrap `Migration.new` so database operations in `initialize` are rolled back on failure

## [0.1.0] - 2025-09-04

- Initial release
