# frozen_string_literal: true

module DataCustoms
  class ThrottledOutput
    def initialize(output, interval:)
      @output = output
      @interval = interval
      @last_printed_at = nil
    end

    def write(line, force: false)
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      return if throttled?(now) && !force

      @last_printed_at = now
      @output.puts(line)
    end

    private

    def throttled?(now)
      @last_printed_at && (now - @last_printed_at) < @interval
    end
  end
end
