# -*- encoding : utf-8 -*-

require File.expand_path('../test_helper', __FILE__)

describe 'CLI with display daemon and share status' do
  it 'should display information about the daemon' do
    gitdocs_assert_status_contains('Running: false')
  end

  it 'should display information about the shares' do
    gitdocs_create(git_init_remote, 'clone1', 'clone2', 'clone3')
    gitdocs_assert_status_contains('clone1', 'clone2', 'clone3')
  end
end
