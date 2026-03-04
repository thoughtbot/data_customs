# frozen_string_literal: true

module DataCustoms
  class Migration
    DEFAULT_BATCH_SIZE = 1000
    DEFAULT_THROTTLE = 0.01

    def self.run(...)
      ActiveRecord::Base.transaction do
        new(...).run
      end
    rescue => e
      warn "🛃 Data migration failed"
      raise e
    end

    def up = raise NotImplementedError
    def verify! = raise NotImplementedError

    def run
      with_progress_reporter do
        up
        verify!
        puts "🛃 Data migration ran successfully!"
      end
    end

    private

    def with_progress_reporter(&block)
      ProgressOutput.wrap do |output|
        @_progress = ProgressReporter.new(output)
        block.call
      end
    end

    def progress = @_progress

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
