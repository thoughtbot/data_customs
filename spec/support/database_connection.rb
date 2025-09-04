require "active_record"

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)

ActiveRecord::Schema.define do
  self.verbose = false

  create_table :test_users, force: true do |t|
    t.string :name
  end
end

class TestUser < ActiveRecord::Base; end
