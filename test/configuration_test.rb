require File.expand_path('../test_helper', __FILE__)

describe "gitdocs configuration" do
  before do
    ShellTools.capture { @config = Gitdocs::Configuration.new("/tmp/gitdocs") }
  end

  it "has sensible default config root" do
    assert_equal "/tmp/gitdocs", @config.config_root
  end

  it "can retrieve empty shares" do
    assert_equal [], @config.shares
  end

  it "can have a path added" do
    @config.add_path('/my/../my/path') # normalized test
    assert_equal "/my/path", @config.shares.first.path
    assert_equal 15.0, @config.shares.first.polling_interval
  end

  it "can have a path removed" do
    @config.add_path('/my/path')
    @config.add_path('/my/path/2')
    @config.remove_path('/my/../my/path/2') # normalized test
    assert_equal ["/my/path"], @config.shares.map(&:path)
  end

  it "can clear paths" do
    @config.add_path('/my/path')
    @config.add_path('/my/path/2')
    @config.clear
    assert_equal [], @config.shares.map(&:path)
  end

  it "can normalize paths" do
    assert_equal File.expand_path("../test_helper.rb", Dir.pwd), @config.normalize_path("../test_helper.rb")
  end
end