class FooBar < DataCustoms::Migration
  def up
    # Your migration code goes here.
  end

  def verify!
    # Your verification code goes here.
    # Raise an exception to cause the migration to fail.
  end
end
