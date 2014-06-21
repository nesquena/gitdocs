# -*- encoding : utf-8 -*-

require File.expand_path('../test_helper', __FILE__)

describe 'CLI with display daemon and share status' do
  it 'should display information about the daemon' do
    gitdocs_status
    assert_gitdocs_status_contains(Gitdocs::VERSION)
    assert_gitdocs_status_contains('Running: false')
  end

  it 'should display information about the shares' do
    git_clone_and_gitdocs_add(git_init_remote, 'clone1', 'clone2', 'clone3')

    gitdocs_status

    assert_gitdocs_status_contains(abs_current_dir('clone1'))
    assert_gitdocs_status_contains(abs_current_dir('clone2'))
    assert_gitdocs_status_contains(abs_current_dir('clone3'))
  end
end
