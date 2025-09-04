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
