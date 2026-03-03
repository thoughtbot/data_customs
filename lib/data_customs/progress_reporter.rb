# frozen_string_literal: true

module DataCustoms
  class ProgressReporter
    BAR_WIDTH = 20
    PRINT_INTERVAL = 2 # seconds
    ETA_MIN_ELAPSED = 2 # seconds before showing ETA

    def initialize(eta: false, output: $stdout)
      @eta = eta
      @output = output
    end

    def report(percentage)
      percentage = percentage.floor.clamp(0, 100)

      if percentage == 100
        @output.puts bar(percentage)
        return
      end

      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @started_at ||= now
      return if throttled?(now)

      @last_printed_at = now
      line = bar(percentage)

      if @eta && percentage > 0
        elapsed = now - @started_at
        if elapsed >= ETA_MIN_ELAPSED
          remaining = elapsed / percentage * (100 - percentage)
          line += " (#{format_duration(remaining)} left)"
        else
          line += " (estimating...)"
        end
      end

      @output.puts line
    end

    private

    def bar(percentage)
      filled = percentage / (100 / BAR_WIDTH)
      empty = BAR_WIDTH - filled
      "🛃 Progress: #{"█" * filled}#{"░" * empty} #{percentage}%"
    end

    def throttled?(now)
      @last_printed_at && (now - @last_printed_at) < PRINT_INTERVAL
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
