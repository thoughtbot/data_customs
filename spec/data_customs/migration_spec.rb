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

  describe "#progress" do
    def build_migration(&up_block)
      Class.new(DataCustoms::Migration) do
        define_method(:up, &up_block)
        def verify! = nil
      end
    end

    it "prints a progress bar" do
      migration = build_migration { progress.report(50) }

      expect { migration.run }.to output(
        /🛃 Progress: ██████████░░░░░░░░░░ 50%\n🛃 Data migration ran successfully!/
      ).to_stdout
    end

    it "floors the percentage" do
      migration = build_migration { progress.report(99.9) }

      expect { migration.run }.to output(
        /🛃 Progress: ███████████████████░ 99%\n🛃 Data migration ran successfully!/
      ).to_stdout
    end

    it "clamps to 0-100" do
      migration = build_migration do
        progress.report(-10)
        progress.report(200)
      end

      expect { migration.run }.to output(
        /🛃 Progress: ░░░░░░░░░░░░░░░░░░░░ 0%\n🛃 Progress: ████████████████████ 100%\n🛃 Data migration ran successfully!/
      ).to_stdout
    end

    it "always prints at 100%" do
      migration = build_migration do
        progress.report(50)
        progress.report(100)
      end

      expect { migration.run }.to output(
        /🛃 Progress: ██████████░░░░░░░░░░ 50%\n🛃 Progress: ████████████████████ 100%\n🛃 Data migration ran successfully!/
      ).to_stdout
    end

    it "throttles output to every 1 second" do
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      # first call is from ProgressReporter.new in run
      timestamps = [now, now, now + 0.3, now + 0.6, now + 1.1]
      allow(Process).to receive(:clock_gettime).and_return(*timestamps)

      migration = build_migration do
        progress.report(10)
        progress.report(20)
        progress.report(30)
        progress.report(40)
      end

      expect { migration.run }.to output(
        /🛃 Progress: ██░░░░░░░░░░░░░░░░░░ 10%\n🛃 Progress: ████████░░░░░░░░░░░░ 40%\n🛃 Data migration ran successfully!/
      ).to_stdout
    end

    it "shows 'estimating...' before enough time has elapsed" do
      migration = Class.new(DataCustoms::Migration) do
        progress eta: true
        define_method(:up) { progress.report(50) }
        def verify! = nil
      end

      expect { migration.run }.to output(
        /Progress: .+ 50% \(estimating\.\.\.\)\n/
      ).to_stdout
    end

    it "shows ETA after enough time has elapsed" do
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      # ProgressReporter.new, report(25) eta + throttle, report(50) eta + throttle
      allow(Process).to receive(:clock_gettime).and_return(now, now, now, now + 5.0, now + 5.0)

      migration = Class.new(DataCustoms::Migration) do
        progress eta: true
        define_method(:up) do
          progress.report(25)
          progress.report(50)
        end
        def verify! = nil
      end

      expect { migration.run }.to output(
        /Progress: .+ 50% \(\d+s left\)\n/
      ).to_stdout
    end

    it "shows elapsed time at 100%" do
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      # first call is from ProgressReporter.new, then report(50) at +0, report(100) at +65
      allow(Process).to receive(:clock_gettime).and_return(now, now, now + 65.0)

      migration = build_migration do
        progress.report(50)
        progress.report(100)
      end

      expect { migration.run }.to output(
        /🛃 Progress: ████████████████████ 100% \(1m 5s elapsed\)\n/
      ).to_stdout
    end

    it "does not show ETA at 0% or 100%" do
      migration = Class.new(DataCustoms::Migration) do
        progress eta: true
        define_method(:up) do
          progress.report(0)
          progress.report(100)
        end
        def verify! = nil
      end

      expect { migration.run }.to output(
        "🛃 Progress: ░░░░░░░░░░░░░░░░░░░░ 0%\n" \
        "🛃 Progress: ████████████████████ 100%\n" \
        "🛃 Data migration ran successfully!\n"
      ).to_stdout
    end
  end

  describe ".progress" do
    it "configures ETA at the class level" do
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      allow(Process).to receive(:clock_gettime).and_return(now, now, now, now + 5.0, now + 5.0)

      migration = Class.new(DataCustoms::Migration) do
        progress eta: true
        define_method(:up) do
          progress.report(25)
          progress.report(50)
        end
        def verify! = nil
      end

      expect { migration.run }.to output(
        /Progress: .+ 50% \(\d+s left\)\n/
      ).to_stdout
    end
  end

  describe "non-atomic migration" do
    it "does not wrap in a transaction (changes persist on failure)" do
      migration = Class.new(DataCustoms::Migration) do
        atomic false

        def up
          TestUser.create!(name: "persisted")
          raise "Boom"
        end

        def verify! = nil
        def down = nil
      end

      expect { migration.run }.to raise_error("Boom")
      expect(TestUser.exists?(name: "persisted")).to be true
    end

    it "calls down when up fails" do
      migration = Class.new(DataCustoms::Migration) do
        atomic false

        def up
          TestUser.create!(name: "to_revert")
          raise "Boom"
        end

        def verify! = nil

        def down
          TestUser.where(name: "to_revert").delete_all
        end
      end

      expect { migration.run }.to raise_error("Boom")
      expect(TestUser.exists?(name: "to_revert")).to be false
    end

    it "calls down when verify! fails" do
      migration = Class.new(DataCustoms::Migration) do
        atomic false

        def up
          TestUser.create!(name: "to_revert")
        end

        def verify!
          raise "Verification failed"
        end

        def down
          TestUser.where(name: "to_revert").delete_all
        end
      end

      expect { migration.run }.to raise_error("Verification failed")
      expect(TestUser.exists?(name: "to_revert")).to be false
    end

    it "warns and re-raises the original error if down also fails" do
      migration = Class.new(DataCustoms::Migration) do
        atomic false

        def up = raise "Original error"
        def verify! = nil
        def down = raise "Down error"
      end

      expect { migration.run }
        .to raise_error("Original error")
        .and output(/down failed: Down error/).to_stderr
    end

    it "succeeds without calling down" do
      migration = Class.new(DataCustoms::Migration) do
        atomic false

        def up
          TestUser.create!(name: "kept")
        end

        def verify!
          raise "Missing!" unless TestUser.exists?(name: "kept")
        end

        def down
          raise "down should not be called"
        end
      end

      expect { migration.run }.to(
        change { TestUser.count }.by(1)
          .and(output("🛃 Data migration ran successfully!\n").to_stdout)
      )
    end

    it "raises ArgumentError if down is not defined" do
      migration = Class.new(DataCustoms::Migration) do
        atomic false

        def up = nil
        def verify! = nil
      end

      expect { migration.run }.to raise_error(ArgumentError, /down method is required/)
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
      expect_any_instance_of(Kernel).not_to receive(:sleep)

      expect { migration.run }.to output("🛃 Data migration ran successfully!\n").to_stdout
    end

    it "throttles between batches in non-atomic mode" do
      3.times { |i| TestUser.create!(name: "User #{i}") }

      migration = Class.new(DataCustoms::Migration) do
        atomic false

        def initialize = @batch_sizes = []

        def up
          batch(TestUser.all, batch_size: 2) do |relation|
            @batch_sizes << relation.size
          end
        end

        def verify!
          raise "Wrong batches #{@batch_sizes}" if @batch_sizes != [2, 1]
        end

        def down = nil
      end
      expect_any_instance_of(Kernel).to receive(:sleep).exactly(2).times

      expect { migration.run }.to output("🛃 Data migration ran successfully!\n").to_stdout
    end

    it "finds each record" do
      3.times { |i| TestUser.create!(name: "User #{i}") }

      migration = Class.new(DataCustoms::Migration) do
        def initialize = @users = []

        def up
          find_each(TestUser.all) do |user|
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
