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
    assert_partial_output("Added path local to doc list", output_from(cmd))
  end

  it 'should remove a share' do
    git_init_local
    gitdocs_add

    cmd = 'gitdocs rm local --pid=gitdocs.pid'
    run_simple(cmd, true, 15)
    assert_success(true)
    assert_partial_output("Removed path local from doc list", output_from(cmd))
  
    gitdocs_status
    assert_gitdocs_status_not_contain(abs_current_dir('local'))
  end

  it 'should clear all existing shares' do
    ['local1', 'local2', 'local3'].each { |x| git_init_local(x) ; gitdocs_add(x) }

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
