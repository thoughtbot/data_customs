# frozen_string_literal: true

RSpec.describe DataCustoms::Migration do
  before do
    TestUser.delete_all
  end

  it "runs and commits if everything succeeds" do
    migration = Class.new(DataCustoms::Migration) do
      def initialize(name:)
        @name = name
      end

      def up
        TestUser.create!(name: @name)
      end

      def verify!
        raise "Verification failed" unless TestUser.exists?(name: @name)
      end
    end

    expect { migration.run(name: "Anonymous") }.to(
      change { TestUser.count }.by(1)
        .and(output("🛃 Data migration ran successfully!\n").to_stdout)
    )
  end

  it "rolls back if verify! fails" do
    migration = Class.new(DataCustoms::Migration) do
      def up
        TestUser.create!(name: "Anonymous")
      end

      def verify! = raise "Always fails"
    end

    expect { migration.run }.to output("🛃 Data migration failed\n").to_stderr
      .and raise_error("Always fails")
      .and change { TestUser.count }.by(0)
  end

  it "rolls back if up crashes" do
    migration = Class.new(DataCustoms::Migration) do
      def up = raise "Kaboom"

      def verify! = raise "Should not reach this"
    end

    expect { migration.run }
      .to output("🛃 Data migration failed\n").to_stderr
      .and raise_error("Kaboom")
  end

  it "rolls back db operations in initialize if up fails" do
    migration = Class.new(DataCustoms::Migration) do
      def initialize
        TestUser.create!(name: "Created in initialize")
      end

      def up = raise "Kaboom"
      def verify! = nil
    end

    expect { migration.run }
      .to raise_error("Kaboom")
      .and change { TestUser.count }.by(0)
  end

  describe "#report_progress" do
    def build_migration(&up_block)
      Class.new(DataCustoms::Migration) do
        define_method(:up, &up_block)
        def verify! = nil
      end
    end

    it "prints a progress bar" do
      migration = build_migration { report_progress(50) }

      expect { migration.run }.to output(
        "🛃 Progress: ██████████░░░░░░░░░░ 50%\n"\
        "🛃 Data migration ran successfully!\n"
      ).to_stdout
    end

    it "floors the percentage" do
      migration = build_migration { report_progress(99.9) }

      expect { migration.run }.to output(
        "🛃 Progress: ███████████████████░ 99%\n"\
        "🛃 Data migration ran successfully!\n"
      ).to_stdout
    end

    it "clamps to 0-100" do
      migration = build_migration do
        report_progress(-10)
        report_progress(200)
      end

      expect { migration.run }.to output(
        "🛃 Progress: ░░░░░░░░░░░░░░░░░░░░ 0%\n"\
        "🛃 Progress: ████████████████████ 100%\n"\
        "🛃 Data migration ran successfully!\n"
      ).to_stdout
    end

    it "deduplicates consecutive calls with same percentage" do
      migration = build_migration do
        report_progress(50)
        report_progress(50.4)
        report_progress(50.9)
        report_progress(51)
      end

      expect { migration.run }.to output(
        "🛃 Progress: ██████████░░░░░░░░░░ 50%\n"\
        "🛃 Progress: ██████████░░░░░░░░░░ 51%\n"\
        "🛃 Data migration ran successfully!\n"
      ).to_stdout
    end

    it "shows ETA when eta: true" do
      migration = build_migration do
        report_progress(10, eta: true)
        report_progress(50, eta: true)
      end

      expect { migration.run }.to output(
        /Progress: .+ 10% \(\d+s left\)\n.*Progress: .+ 50% \(\d+s left\)\n/
      ).to_stdout
    end

    it "does not show ETA at 0% or 100%" do
      migration = build_migration do
        report_progress(0, eta: true)
        report_progress(100, eta: true)
      end

      expect { migration.run }.to output(
        "🛃 Progress: ░░░░░░░░░░░░░░░░░░░░ 0%\n"\
        "🛃 Progress: ████████████████████ 100%\n"\
        "🛃 Data migration ran successfully!\n"
      ).to_stdout
    end

    it "does not collide with task output" do
      migration = build_migration do
        report_progress(50)
        puts "Processing..."
        report_progress(100)
      end

      expect { migration.run }.to output(
        "🛃 Progress: ██████████░░░░░░░░░░ 50%\n"\
        "Processing...\n"\
        "🛃 Progress: ████████████████████ 100%\n"\
        "🛃 Data migration ran successfully!\n"
      ).to_stdout
    end
  end

  describe "helpers" do
    it "batches records" do
      3.times { |i| TestUser.create!(name: "User #{i}") }

      migration = Class.new(DataCustoms::Migration) do
        def initialize = @batch_sizes = []

        def up
          batch(TestUser.all, batch_size: 2) do |relation|
            @batch_sizes << relation.size
          end
        end

        def verify!
          raise "Wrong batches #{@batch_sizes}" if @batch_sizes != [2, 1]
        end
      end
      expect_any_instance_of(Kernel).to receive(:sleep).exactly(2).times

      expect { migration.run }.to output("🛃 Data migration ran successfully!\n").to_stdout
    end

    it "finds each record" do
      allow_any_instance_of(Kernel).to receive(:sleep)
      3.times { |i| TestUser.create!(name: "User #{i}") }

      migration = Class.new(DataCustoms::Migration) do
        def initialize = @users = []

        def up
          find_each(TestUser.all, throttle_seconds: -1) do |user|
            @users << user.name
          end
        end

        def verify!
          raise "Wrong users #{@users}" if @users != ["User 0", "User 1", "User 2"]
        end
      end
      expect_any_instance_of(Kernel).not_to receive(:sleep)

      expect { migration.run }.to output("🛃 Data migration ran successfully!\n").to_stdout
    end
  end
end
