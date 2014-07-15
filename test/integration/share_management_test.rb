# -*- encoding : utf-8 -*-

require File.expand_path('../test_helper', __FILE__)

describe 'Manage which shares are being watched' do
  it 'should add a local repository' do
    git_init_local
    gitdocs_add
    gitdocs_status
    assert_gitdocs_status_contains(abs_current_dir('local'))
  end

  it 'should add a remote repository' do
    git_init_remote
    abs_remote_path = abs_current_dir('remote')
    cmd = "gitdocs create local #{abs_remote_path} --pid=gitdocs.pid"
    run_simple(cmd, true, 15)
    assert_success(true)
    assert_partial_output('Added path local to doc list', output_from(cmd))
  end

  it 'should update a share through the UI' do
    git_init_local
    gitdocs_add
    start_daemon
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
      cmd = 'gitdocs rm local --pid=gitdocs.pid'
      run_simple(cmd, true, 15)
      assert_success(true)
      assert_partial_output('Removed path local from doc list', output_from(cmd))

      gitdocs_status
      assert_gitdocs_status_not_contain(abs_current_dir('local'))
    end

    it 'through UI' do
      start_daemon
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

    cmd = 'gitdocs clear --pid=gitdocs.pid'
    run_simple(cmd, true, 15)
    assert_success(true)
    assert_partial_output('Cleared paths from gitdocs', output_from(cmd))

    gitdocs_status
    assert_gitdocs_status_not_contain(abs_current_dir('local1'))
    assert_gitdocs_status_not_contain(abs_current_dir('local2'))
    assert_gitdocs_status_not_contain(abs_current_dir('local3'))
  end
end
