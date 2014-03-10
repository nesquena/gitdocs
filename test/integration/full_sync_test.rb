require File.expand_path('../test_helper', __FILE__)

describe 'fully synchronizing repositories' do
  before do
    git_clone_and_gitdocs_add(git_init_remote, 'clone1', 'clone2', 'clone3')

    # TODO: apply this configuration through the CLI in future
    configuration = Gitdocs::Configuration.new
    configuration.shares.each do |share|
      share.update_attributes(polling_interval: 0.1, notification: false)
    end
    configuration.global.update_attributes(load_browser_on_startup: false)

    start_cmd = 'gitdocs start --debug --pid=gitdocs.pid --port 7777'
    run(start_cmd, 15)
    assert_success(true)
    assert_partial_output('Started gitdocs', output_from(start_cmd))
  end

  it 'should sync new files' do
    write_file('clone1/newfile', 'testing')

    sleep 3
    check_file_presence(['clone2/newfile', 'clone3/newfile'], true)
    check_exact_file_content('clone1/newfile', 'testing')
    check_exact_file_content('clone2/newfile', 'testing')
    check_exact_file_content('clone3/newfile', 'testing')
  end

  it 'should sync changes to an existing file' do
    write_file('clone1/file', 'testing')
    sleep(3) # Allow the initial files to sync

    append_to_file('clone3/file', "\nfoobar")

    sleep(3)
    check_exact_file_content('clone1/file', "testing\nfoobar")
    check_exact_file_content('clone2/file', "testing\nfoobar")
    check_exact_file_content('clone3/file', "testing\nfoobar")
  end

  it 'should sync empty directories' do
    in_current_dir { _mkdir('clone1/empty_dir') }
    sleep(3)

    check_directory_presence(
      ['clone1/empty_dir', 'clone2/empty_dir', 'clone3/empty_dir'],
      true
    )
  end

  it 'should mark unresolvable conflicts' do
    write_file('clone1/file', 'testing')
    sleep(3) # Allow the initial files to sync

    append_to_file('clone2/file', 'foobar')
    append_to_file('clone3/file', 'deadbeef')

    sleep(3)
    in_current_dir do
      # Remember expected file counts include '.', '..', and '.git'
      assert_equal(6, Dir.entries('clone1').count)
      assert_equal(6, Dir.entries('clone2').count)
      assert_equal(6, Dir.entries('clone3').count)
    end
  end
end
