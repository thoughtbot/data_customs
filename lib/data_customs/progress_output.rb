# frozen_string_literal: true

module DataCustoms
  class ProgressOutput
    def self.wrap
      real_output = $stdout
      tty = real_output.respond_to?(:tty?) && real_output.tty?

      if tty
        tui = new(real_output)
        $stdout = tui.buffer
        yield tui
      else
        yield real_output
      end
    ensure
      $stdout = real_output
      tui&.flush
    end

    attr_reader :buffer

    def initialize(output)
      @output = output
      @buffer = StringIO.new
      @buffer_flushed_to = 0
      output.print "\e[H\e[2J" # Clear screen and move cursor to top-left
    end

    def puts(line)
      @output.print "\e[H" # Move cursor to top-left
      "#{line}\n#{@buffer.string}".each_line do |l|
        @output.print "\e[2K#{l}" # Clear line and print new content
      end
      @buffer_flushed_to = @buffer.string.length
    end

    def flush
      remaining = @buffer.string[@buffer_flushed_to..]
      @output.write(remaining) if remaining && !remaining.empty?
    end
  end
end
