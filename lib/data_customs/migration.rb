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
      up
      verify!
      puts "🛃 Data migration ran successfully!"
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

    def report_progress(percentage, eta: false)
      percentage = percentage.floor.clamp(0, 100)
      return if percentage == @_last_reported_progress

      @_last_reported_progress = percentage
      filled = percentage / 5
      empty = 20 - filled
      progress = "🛃 Progress: #{"█" * filled}#{"░" * empty} #{percentage}%"

      if eta && percentage.between?(1, 99)
        @_progress_started_at ||= Process.clock_gettime(Process::CLOCK_MONOTONIC)
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @_progress_started_at
        remaining = elapsed / percentage * (100 - percentage)
        progress += " (#{format_duration(remaining)} left)"
      end

      puts progress
    end

    def format_duration(seconds)
      seconds = seconds.ceil
      if seconds < 60
        "#{seconds}s"
      elsif seconds < 3600
        "#{seconds / 60}m #{seconds % 60}s"
      else
        "#{seconds / 3600}h #{(seconds % 3600) / 60}m"
      end
    end
  end
end
