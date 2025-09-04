# frozen_string_literal: true

RSpec.describe "Rake tasks" do
  describe "data_migration:run" do
    it "runs a data migration" do
      stdout, stderr, status = run_command("bundle exec rake data_customs:run NAME=TestMigration", chdir: dummy_app_root)

      expect(status.success?).to be(true), -> { "stdout:\n#{stdout}\nstderr:\n#{stderr}" }
      expect(stdout).to include("Data migration ran successfully!")
      expect(stdout).to include("up")
      expect(stdout).to include("verify!")
    end

    it "accepts accepts arguments" do
      stdout, stderr, status = run_command("bundle exec rake data_customs:run NAME=test_migration ARGS=arg1,arg2", chdir: dummy_app_root)

      expect(status.success?).to be(true), -> { "stdout:\n#{stdout}\nstderr:\n#{stderr}" }
      expect(stdout).to include("Data migration ran successfully!")
      expect(stdout).to include("up with args: [\"arg1\", \"arg2\"]")
      expect(stdout).to include("verify!")
    end

    context "when migration name is missing" do
      it "shows an error message" do
        stdout, stderr, status = run_command("bundle exec rake data_customs:run", chdir: dummy_app_root)

        expect(status.success?).to be(false), -> { "stdout:\n#{stdout}\nstderr:\n#{stderr}" }
        expect(stderr).to include("❌ Missing migration name")
      end
    end

    context "when migration file does not exist" do
      it "shows an error message" do
        stdout, stderr, status = run_command("bundle exec rake data_customs:run NAME=non_existent_migration", chdir: dummy_app_root)

        expect(status.success?).to be(false), -> { "stdout:\n#{stdout}\nstderr:\n#{stderr}" }
        expect(stderr).to include("❌ Migration not found")
      end
    end
  end
end
