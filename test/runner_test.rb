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

  it "should resolve conflicts files" do
    with_clones(3) do |clone1, clone2, clone3|
      File.open(File.join(clone1, "test.txt"), 'w') { |f| f << "testing" }
      sleep 2
      File.open(File.join(clone1, "test.txt"), 'w') { |f| f << "testing\n1" }
      File.open(File.join(clone2, "test.txt"), 'w') { |f| f << "testing\n2" }
      sleep 2
      assert_equal "testing", File.read(File.join(clone1, "test-original.txt"))
      test_1 = File.read(File.join(clone1, "test-1.txt"))
      test_2 = File.read(File.join(clone1, "test-2.txt"))
      assert_equal "testing", File.read(File.join(clone2, "test-original.txt"))
      assert_equal test_1,    File.read(File.join(clone2, "test-1.txt"))
      assert_equal test_2,    File.read(File.join(clone2, "test-2.txt"))
      assert_equal "testing", File.read(File.join(clone3, "test-original.txt"))
      assert_equal test_1,    File.read(File.join(clone3, "test-1.txt"))
      assert_equal test_2,    File.read(File.join(clone3, "test-2.txt"))
    end
  end
end