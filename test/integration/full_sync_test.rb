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
    # TODO: check the change is committed and pushed

    sleep 3
    check_file_presence(['clone2/newfile', 'clone3/newfile'], true)
    check_exact_file_content('clone2/newfile', 'testing')
    check_exact_file_content('clone3/newfile', 'testing')
  end

#Scenario: Sync changes to an existing file

#Scenario: Resolve conflicts between 2 changes
#Scenario: Mark unresolvable conflicts
#  When a change is made in 1 repository
#    And a conflicting change is made in another repository
#  Then all the repositories should contain the conflict markers
end
