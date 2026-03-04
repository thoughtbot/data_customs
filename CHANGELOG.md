## [Unreleased]

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
```

- Fix transaction to wrap `Migration.new` so database operations in `initialize` are rolled back on failure

## [0.1.0] - 2025-09-04

- Initial release
