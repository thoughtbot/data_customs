# frozen_string_literal: true

RSpec.describe DataCustoms::ProgressReporter do
  it "calls puts on the output with the formatted line" do
    output = StringIO.new
    reporter = described_class.new(output)

    reporter.report(50)

    expect(output.string).to eq("🛃 Progress: ██████████░░░░░░░░░░ 50%\n")
  end
end
