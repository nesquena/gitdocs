# -*- encoding : utf-8 -*-

require File.expand_path('../test_helper', __FILE__)

describe 'fully synchronizing repositories' do
  before do
    gitdocs_create_from_remote('clone1', 'clone2', 'clone3')
    gitdocs_start
  end

  it 'should sync new files' do
    GitFactory.write(:clone1, 'newfile', 'testing')
    assert_clean(:clone1)

    assert_file_content(:clone1, 'newfile', 'testing')
    assert_file_content(:clone2, 'newfile', 'testing')
    assert_file_content(:clone3, 'newfile', 'testing')
  end

  it 'should sync changes to an existing file' do
    GitFactory.write(:clone1, 'file', 'testing')
    assert_clean(:clone1)

    assert_file_content(:clone3, 'file', 'testing')
    GitFactory.append(:clone3, 'file', "\nfoobar")
    assert_clean(:clone3)

    assert_file_content(:clone1, 'file', "testing\nfoobar")
    assert_file_content(:clone2, 'file', "testing\nfoobar")
    assert_file_content(:clone3, 'file', "testing\nfoobar")
  end

  it 'should sync empty directories' do
    GitFactory.mkdir(:clone1, 'empty_dir')
    assert_clean(:clone1)

    assert_file_exist(:clone1, 'empty_dir')
    assert_file_exist(:clone2, 'empty_dir')
    assert_file_exist(:clone3, 'empty_dir')
  end

  it 'should mark unresolvable conflicts' do
    # HACK: This scenario is so dependent upon timing, that is does not run
    # reliably on TravisCI, even when it is passing locally.
    # So skip it.
    next if ENV['TRAVIS']

    GitFactory.write(:clone1, 'file', 'testing')
    assert_clean(:clone1)

    GitFactory.append(:clone2, 'file', 'foobar')
    GitFactory.append(:clone3, 'file', 'deadbeef')
    assert_clean(:clone2)
    assert_clean(:clone3)

    %w(clone2 clone3 clone1).each do |repo_name|
      assert_file_exist(repo_name, 'file (9a2c773)')
      assert_file_exist(repo_name, 'file (f6ea049)')
      assert_file_exist(repo_name, 'file (e8b5f82)')
    end
  end
end

################################################################################

# @param (see GitInspector.clean?)
def assert_clean(repo_name)
  wait_for_assert { GitInspector.clean?(repo_name).must_equal(true) }
end

# @param [#to_s] repo_name
# @param [String] filename
# @param [String] content
def assert_file_content(repo_name, filename, content)
  wait_for_assert do
    GitInspector.file_content(repo_name, filename).must_equal(content)
  end
end

# @param (see GitInspector.file_exist?)
def assert_file_exist(repo_name, filename)
  wait_for_assert { GitInspector.file_exist?(repo_name, filename).must_equal(true) }
end
