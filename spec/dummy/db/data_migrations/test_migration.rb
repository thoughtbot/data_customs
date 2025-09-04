class TestMigration < DataCustoms::Migration
  def initialize(args = nil)
    @args = args
  end

  def up
    if @args
      puts "up with args: #{@args.inspect}"
    else
      puts "up"
    end
  end

  def verify!
    puts "verify!"
  end
end
