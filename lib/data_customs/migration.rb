# frozen_string_literal: true

module DataCustoms
  class Migration
    DEFAULT_BATCH_SIZE = 1000
    DEFAULT_THROTTLE = 0.01
    PROGRESS_BAR_WIDTH = 20
    PROGRESS_PRINT_INTERVAL = 2 # seconds
    ETA_MIN_ELAPSED = 2 # seconds before showing ETA

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

      if percentage == 100
        puts progress_bar(percentage)
        return
      end

      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @_progress_started_at ||= now
      return if throttled?(now)

      @_last_progress_printed_at = now
      progress = progress_bar(percentage)

      if eta && percentage > 0
        elapsed = now - @_progress_started_at
        if elapsed >= ETA_MIN_ELAPSED
          remaining = elapsed / percentage * (100 - percentage)
          progress += " (#{format_duration(remaining)} left)"
        else
          progress += " (estimating...)"
        end
      end

      puts progress
    end

    def progress_bar(percentage)
      filled = percentage / (100 / PROGRESS_BAR_WIDTH)
      empty = PROGRESS_BAR_WIDTH - filled
      "🛃 Progress: #{"█" * filled}#{"░" * empty} #{percentage}%"
    end

    def throttled?(now)
      @_last_progress_printed_at && (now - @_last_progress_printed_at) < PROGRESS_PRINT_INTERVAL
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
