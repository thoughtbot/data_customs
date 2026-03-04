# frozen_string_literal: true

RSpec.describe DataCustoms::ProgressOutput do
  def tty_output
    StringIO.new.tap { |io| allow(io).to receive(:tty?).and_return(true) }
  end

  describe ".wrap" do
    it "yields a ProgressOutput and redirects $stdout to buffer in TTY mode" do
      output = tty_output
      $stdout = output

      described_class.wrap do |tui|
        expect(tui).to be_a(described_class)
        expect($stdout).not_to eq(output)
      end
    ensure
      $stdout = STDOUT
    end

    it "yields $stdout in non-TTY mode" do
      $stdout = StringIO.new

      described_class.wrap do |output|
        expect(output).to eq($stdout)
      end
    ensure
      $stdout = STDOUT
    end

    it "restores $stdout after the block" do
      output = tty_output
      $stdout = output

      described_class.wrap { |_| }

      expect($stdout).to eq(output)
    ensure
      $stdout = STDOUT
    end
  end

  describe "#puts" do
    it "repaints progress on top with buffer below" do
      output = tty_output
      tui = described_class.new(output)

      tui.buffer.puts("hello")
      tui.puts("progress line")

      expect(output.string).to include("\e[2Kprogress line\n\e[2Khello\n")
    end
  end

  describe "#flush" do
    it "writes remaining buffer after last repaint" do
      output = tty_output
      tui = described_class.new(output)

      tui.puts("progress")
      tui.buffer.puts("after repaint")
      tui.flush

      expect(output.string).to end_with("after repaint\n")
    end

    it "is a no-op when buffer has no new content" do
      output = tty_output
      tui = described_class.new(output)

      tui.puts("progress")
      before = output.string.dup
      tui.flush

      expect(output.string).to eq(before)
    end
  end
end
