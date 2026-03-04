# frozen_string_literal: true

module DataCustoms
  class ProgressReporter
    BAR_WIDTH = 20
    PRINT_INTERVAL = 1 # seconds
    ETA_MIN_ELAPSED = 2 # seconds before showing ETA

    def initialize(output)
      @output = ThrottledOutput.new(output, interval: PRINT_INTERVAL)
      @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def report(percentage, eta: false)
      percentage = percentage.floor.clamp(0, 100)
      line = bar(percentage)

      if percentage == 100
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at
        line += " (#{format_duration(elapsed)} elapsed)" if elapsed >= 1
        @output.write(line, force: true)
        return
      end

      if eta && percentage > 0
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at
        if elapsed >= ETA_MIN_ELAPSED
          remaining = elapsed / percentage * (100 - percentage)
          line += " (#{format_duration(remaining)} left)"
        else
          line += " (estimating...)"
        end
      end

      @output.write(line)
    end

    private

    def bar(percentage)
      filled = percentage / (100 / BAR_WIDTH)
      empty = BAR_WIDTH - filled
      "🛃 Progress: #{"█" * filled}#{"░" * empty} #{percentage}%"
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
