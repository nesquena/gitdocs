# -*- encoding : utf-8 -*-

require File.expand_path('../test_helper', __FILE__)

describe 'gitdocs configuration' do
  before do
    ENV['TEST'] = 'true'
    ShellTools.capture { @config = Gitdocs::Configuration.new('/tmp/gitdocs') }
  end

  it 'has sensible default config root' do
    assert_equal '/tmp/gitdocs', @config.config_root
  end

  it 'can retrieve empty shares' do
    assert_equal [], @config.shares
  end

  it 'can have a path added' do
    @config.add_path('/my/../my/path') # normalized test
    assert_equal '/my/path', @config.shares.first.path
    assert_equal 15.0, @config.shares.first.polling_interval
  end

  it 'can have a path removed' do
    @config.add_path('/my/path')
    @config.add_path('/my/path/2')
    @config.remove_path('/my/../my/path/2') # normalized test
    assert_equal ['/my/path'], @config.shares.map(&:path)
  end

  it 'can have a share removed by id' do
    @config.add_path('/my/path')
    @config.add_path('/my/path/2')

    # Delete an index which exists
    @config.remove_by_id(2).must_equal(true) # normalized test
    assert_equal ['/my/path'], @config.shares.map(&:path)

    # Try to delete an index which does not exist
    @config.remove_by_id(5).must_equal(false) # normalized test
    assert_equal ['/my/path'], @config.shares.map(&:path)
  end

  it 'can clear paths' do
    @config.add_path('/my/path')
    @config.add_path('/my/path/2')
    @config.clear
    assert_equal [], @config.shares.map(&:path)
  end

  it 'can normalize paths' do
    assert_equal File.expand_path('../test_helper.rb', Dir.pwd), @config.normalize_path('../test_helper.rb')
  end

  describe '#update_all' do
    before do
      @config.add_path('/my/path')
      @config.add_path('/my/path/2')
      @config.add_path('/my/path/3')
      @config.add_path('/my/path/4')
      @config.add_path('/my/path/5')
      @config.update_all(
        'config' => { 'start_web_frontend' => false, 'web_frontend_port' => 9999 },
        'share'  => {
          '0' => { 'path' => '/my/path',    'polling_interval' => 42 },
          '1' => { 'path' => '/my/path/2',  'polling_interval' => 66 },
          '2' => { 'path' => '/my/path/3a', 'polling_interval' => 77 },
          '3' => { 'path' => '',            'polling_interval' => 88 },
          '4' => {                          'polling_interval' => 99 }
        }
      )
    end
    it { @config.shares.size.must_equal(5) }
    it { @config.shares[0].path.must_equal('/my/path') }
    it { @config.shares[0].polling_interval.must_equal(42) }
    it { @config.shares[1].path.must_equal('/my/path/2') }
    it { @config.shares[1].polling_interval.must_equal(66) }
    it { @config.shares[2].path.must_equal('/my/path/3a') }
    it { @config.shares[2].polling_interval.must_equal(77) }
    it { @config.shares[3].path.must_equal('/my/path/4') }
    it { @config.shares[3].polling_interval.must_equal(15) }
    it { @config.shares[4].path.must_equal('/my/path/5') }
    it { @config.shares[4].polling_interval.must_equal(15) }
  end
end
