# -*- encoding : utf-8 -*-

require File.expand_path('../../test_helper', __FILE__)

describe 'Manage which shares are being watched' do
  it 'should add a local repository' do
    gitdocs_add('local')
    gitdocs_assert_status_contains('local')
  end

  it 'should add a remote repository' do
    gitdocs_create_from_remote('local')
  end

  describe 'remove a share' do
    before { gitdocs_add('local') }
    it do
      gitdocs_command('rm', 'local', 'Removed path local from doc list')
      gitdocs_assert_status_not_contain('local')
    end
  end

  it 'should clear all existing shares' do
    %w(local1 local2 local3).each { |x| gitdocs_add(x) }

    gitdocs_command('clear', 'Cleared paths from gitdocs')
    gitdocs_assert_status_not_contain('local1', 'local2', 'local3')
  end
end
