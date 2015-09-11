# -*- encoding : utf-8 -*-

require File.expand_path('../test_helper', __FILE__)

describe 'Manage which shares are being watched' do
  it 'should add a local repository' do
    git_init_local
    gitdocs_add
    gitdocs_assert_status_contains('local')
  end

  it 'should add a remote repository' do
    git_init_remote
    gitdocs_command(
      'create',
      "local #{abs_current_dir('remote')}",
      'Added path local to doc list'
    )
  end

  it 'should update a share through the UI' do
    git_init_local
    gitdocs_add
    gitdocs_start
    visit('http://localhost:7777/')
    click_link('Settings')

    within('#settings') do
      within('#share-0') do
        fill_in('share[0][polling_interval]', with: '0.2')
        select('Fetch only', from: 'share[0][sync_type]')
      end
      click_button('Save')
    end

    # Allow the asynchronous portion of the update finish before checking
    # the result.
    sleep(1)

    click_link('Settings')
    within('#settings') do
      within('#share-0') do
        page.must_have_field('share[0][polling_interval]', with: '0.2')
        page.must_have_field('share[0][sync_type]', with: 'fetch')
      end
    end
  end

  describe 'remove a share' do
    before do
      git_init_local
      gitdocs_add
    end

    it 'through CLI' do
      gitdocs_command('rm', 'local', 'Removed path local from doc list')
      gitdocs_assert_status_not_contain('local')
    end

    it 'through UI' do
      gitdocs_start
      visit('http://localhost:7777/')
      click_link('Settings')

      within('#settings') do
        within('#share-0') { click_link('Delete') }

        page.must_have_css('.share', count: 0)
      end
    end
  end

  it 'should clear all existing shares' do
    %w(local1 local2 local3).each do |path|
      git_init_local(path)
      gitdocs_add(path)
    end

    gitdocs_command('clear', '', 'Cleared paths from gitdocs')
    gitdocs_assert_status_not_contain('local1', 'local2', 'local3')
  end
end
