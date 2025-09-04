# frozen_string_literal: true

module DataCustoms
  class Migration
    DEFAULT_BATCH_SIZE = 1000
    DEFAULT_THROTTLE = 0.01

    def self.run(...) = new(...).run

    def up = raise NotImplementedError

    def verify! = raise NotImplementedError

    def run
      ActiveRecord::Base.transaction do
        up
        verify!
        puts "🛃 Data migration ran successfully!"
      rescue => e
        warn "🛃 Data migration failed"
        raise e
      end
    end

    private

    def batch(scope, batch_size: DEFAULT_BATCH_SIZE, throttle_seconds: DEFAULT_THROTTLE)
      scope.in_batches(of: batch_size) do |relation|
        yield relation
        sleep(throttle_seconds) if throttle_seconds.positive?
      end
    end

    def find_each(scope, **, &)
      batch(scope, **) do |relation|
        relation.each(&)
      end
    end
  end
end
