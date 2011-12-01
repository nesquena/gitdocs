require File.expand_path('../test_helper', __FILE__)

describe "gitdocs runner" do
  it "should clone files" do
    with_clones(3) do |clone1, clone2, clone3|
      File.open(File.join(clone1, "test"), 'w') { |f| f << "testing" }
      sleep 2
      assert_equal "testing", File.read(File.join(clone1, "test"))
      assert_equal "testing", File.read(File.join(clone2, "test"))
      assert_equal "testing", File.read(File.join(clone3, "test"))
    end
  end
end