# -*- encoding : utf-8 -*-

require File.expand_path('../test_helper', __FILE__)

describe Gitdocs::Share do
  before do
    ShellTools.capture { Gitdocs::Initializer.initialize_database }
  end

  it 'can retrieve empty shares' do
    assert_equal [], Gitdocs::Share.all.to_a
  end

  it 'can have a path added' do
    Gitdocs::Share.create_by_path!('/my/../my/path') # normalized test
    assert_equal '/my/path', Gitdocs::Share.at(0).path
    assert_equal 15.0, Gitdocs::Share.at(0).polling_interval
  end

  it 'can have a path removed' do
    Gitdocs::Share.create_by_path!('/my/path')
    Gitdocs::Share.create_by_path!('/my/path/2')
    Gitdocs::Share.remove_by_path('/my/../my/path/2') # normalized test
    assert_equal ['/my/path'], Gitdocs::Share.all.map(&:path)
  end

  it 'can have a share removed by id' do
    Gitdocs::Share.create_by_path!('/my/path')
    Gitdocs::Share.create_by_path!('/my/path/2')

    # Delete an index which exists
    Gitdocs::Share.remove_by_id(2).must_equal(true) # normalized test
    assert_equal ['/my/path'], Gitdocs::Share.all.map(&:path)

    # Try to delete an index which does not exist
    Gitdocs::Share.remove_by_id(5).must_equal(false) # normalized test
    assert_equal ['/my/path'], Gitdocs::Share.all.map(&:path)
  end

  describe '#update_all' do
    before do
      Gitdocs::Share.create_by_path!('/my/path')
      Gitdocs::Share.create_by_path!('/my/path/2')
      Gitdocs::Share.create_by_path!('/my/path/3')
      Gitdocs::Share.create_by_path!('/my/path/4')
      Gitdocs::Share.create_by_path!('/my/path/5')

      Gitdocs::Share.update_all(
        '0' => { 'path' => '/my/path',    'polling_interval' => 42 },
        '1' => { 'path' => '/my/path/2',  'polling_interval' => 66 },
        '2' => { 'path' => '/my/path/3a', 'polling_interval' => 77 },
        '3' => { 'path' => '',            'polling_interval' => 88 },
        '4' => {                          'polling_interval' => 99 }
      )
    end
    it { Gitdocs::Share.all.size.must_equal(5) }
    it do
      Gitdocs::Share.all.map(&:path).must_equal(
        %w(/my/path /my/path/2 /my/path/3a /my/path/4 /my/path/5)
      )
    end
    it do
      Gitdocs::Share.all.map(&:polling_interval).must_equal(
        [42, 66, 77, 15, 15]
      )
    end
  end
end
