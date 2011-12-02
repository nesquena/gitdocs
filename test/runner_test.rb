require File.expand_path('../test_helper', __FILE__)

describe "gitdocs runner" do
  it "should clone files" do
    with_clones(3) do |clone1, clone2, clone3|
      File.open(File.join(clone1, "test"), 'w') { |f| f << "testing" }
      sleep 3
      assert_equal "testing", File.read(File.join(clone1, "test"))
      assert_equal "testing", File.read(File.join(clone2, "test"))
      assert_equal "testing", File.read(File.join(clone3, "test"))
    end
  end

  it "should resolve conflicts files" do
    with_clones(3) do |clone1, clone2, clone3|
      File.open(File.join(clone1, "test.txt"), 'w') { |f| f << "testing" }
      sleep 3
      File.open(File.join(clone1, "test.txt"), 'w') { |f| f << "testing\n1" }
      File.open(File.join(clone2, "test.txt"), 'w') { |f| f << "testing\n2" }
      sleep 3
      assert_includes 2..3, Dir[File.join(clone2, "*.txt")].to_a.size
      assert_includes 2..3, Dir[File.join(clone3, "*.txt")].to_a.size
    end
  end
end