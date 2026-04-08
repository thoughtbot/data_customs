# frozen_string_literal: true

module DataCustoms
  class Migration
    DEFAULT_BATCH_SIZE = 1000
    DEFAULT_THROTTLE = 0.01

    def self.atomic(value)
      @atomic = value
    end

    def self.atomic?
      @atomic != false
    end

    def self.progress(**options)
      @progress_options = options
    end

    def self.progress_options
      @progress_options || {}
    end

    def self.run(*args, **kwargs)
      ensure_rollback_strategy!

      with_transaction(*args, **kwargs) do |migration|
        migration.run
      end
    rescue => e
      warn "🛃 Data migration failed"
      raise e
    end

    def self.ensure_rollback_strategy!
      return if atomic? || method_defined?(:down)

      raise ArgumentError, "down method is required when running a non-atomic migration"
    end

    def self.with_transaction(*args, **kwargs)
      if atomic?
        ActiveRecord::Base.transaction do
          yield new(*args, **kwargs)
        end
      else
        migration = new(*args, **kwargs)
        begin
          yield migration
        rescue => e
          begin
            migration.down
          rescue => down_error
            warn "🛃 down failed: #{down_error.message}"
          end
          raise e
        end
      end
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
        @_progress = ProgressReporter.new(output, **self.class.progress_options)
        block.call
      end
    end

    def progress = @_progress

    def default_throttle
      self.class.atomic? ? 0 : DEFAULT_THROTTLE
    end

    def batch(scope, batch_size: DEFAULT_BATCH_SIZE, throttle_seconds: default_throttle)
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
