# -*- encoding : utf-8 -*-

require 'rubygems'
require 'minitest/autorun'
$LOAD_PATH.unshift File.expand_path('../../lib')
require 'gitdocs'
require 'aruba'
require 'aruba/api'
require 'timeout'
require 'capybara'
require 'capybara_minitest_spec'
require 'capybara/poltergeist'
Dir.glob(File.expand_path('../../support/**/*.rb', __FILE__)).each do |filename|
  require_relative filename
end

Capybara.app_host              = 'http://localhost:7777/'
Capybara.default_driver        = :poltergeist
Capybara.run_server            = false
Capybara.default_max_wait_time = 30

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, timeout: Capybara.default_max_wait_time)
end

PID_FILE = File.expand_path('../../../tmp/gitdocs.pid', __FILE__)

module MiniTest::Aruba
  class ArubaApiWrapper
    include Aruba::Api
  end

  def aruba
    @aruba ||= ArubaApiWrapper.new
  end

  def run(*args)
    if args.length == 0
      super
    else
      aruba.run(*args)
    end
  end

  def method_missing(method, *args, &block)
    aruba.send(method, *args, &block)
  end
end

module Helper
  include MiniTest::Aruba
  include Capybara::DSL
  include Capybara::RSpecMatchers

  def before_setup
    FileUtils.rm_rf(current_dir)
    set_env('HOME', abs_current_dir)
    GitFactory.working_directory = abs_current_dir

    FileUtils.mkdir_p(abs_current_dir)
    Rugged::Config.global['user.name']  = GitFactory.users[0][:name]
    Rugged::Config.global['user.email'] = GitFactory.users[0][:email]
  end

  def teardown
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end

  def after_teardown
    restore_env
    processes.clear

    terminate_processes!
    prep_for_fs_check do
      next unless File.exist?(PID_FILE)

      pid = IO.read(PID_FILE).to_i
      Process.kill('KILL', pid)
      begin
        Process.wait(pid)
      rescue SystemCallError # rubocop:disable Lint/HandleExceptions
        # This means that the process is already gone.
        # Nothing to do.
      end
      FileUtils.rm_rf(PID_FILE)
    end

    # Report gitdocs execution details on failure
    unless passed?
      puts "\n\n----------------------------------"
      puts "Aruba details for failure: #{name}"
      puts "#{failures.inspect}"

      log_filename = File.join(abs_current_dir, '.gitdocs', 'log')
      if File.exist?(log_filename)
        puts "Log file: #{log_filename}"
        puts File.read(log_filename)
      end

      if Dir.exist?(abs_current_dir)
        puts '----------------------------------'
        puts 'Aruba current directory file list:'
        Find.find(abs_current_dir) do |path|
          Find.prune if path =~ %r(.git/?$)
          puts "  #{path}"
        end
      end

      puts "----------------------------------\n\n"
    end
  end

  # @param [String] method pass to the CLI
  # @param [String] arguments which will be passed to the CLI in addition
  # @param [String] expected_output that the CLI should return
  #
  # @return [String] full text of the command being executed
  def gitdocs_command(method, arguments, expected_output)
    binary_path  = File.expand_path('../../../bin/gitdocs', __FILE__)
    full_command = "#{binary_path} #{method} #{arguments} --pid=#{PID_FILE}"

    run(full_command, 15)
    assert_success(true)
    assert_partial_output(expected_output, output_from(full_command))

    full_command
  end

  # @return [void]
  def gitdocs_start
    Gitdocs::Initializer.initialize_database
    Gitdocs::Share.all.each do |share|
      share.update_attributes(polling_interval: 0.1, notification: false)
    end

    FileUtils.rm_rf(PID_FILE)
    gitdocs_command('start', '--verbose --port=7777', 'Started gitdocs')
  end

  # @overload abs_current_dir
  #   @return [String] absolute path for current_dir
  # @overload abs_current_dir(relative_path)
  #   @param [String] relative_path to the current directory
  #   @return [String] the absolute path
  def abs_current_dir(relative_path = nil)
    return File.absolute_path(File.join(current_dir)) unless relative_path
    File.absolute_path(File.join(current_dir, relative_path))
  end

  # @param [String] path
  #
  # @return [#gitdocs_command]
  def gitdocs_add(path)
    GitFactory.init(path)
    gitdocs_command('add', path, "Added path #{path} to doc list")
  end

  # @deprecated
  # @param [String] remote_repository_path
  # @param [Array<String>] destination_paths
  def gitdocs_create(remote_repository_path, *destination_paths)
    destination_paths.each do |destination_path|
      gitdocs_command(
        'create',
        "#{destination_path} #{remote_repository_path}",
        "Added path #{destination_path} to doc list"
      )
    end
  end

  # @param [Array<String>] destination_paths
  #
  # @return [void]
  def gitdocs_create_from_remote(*destination_paths)
    full_destination_paths = destination_paths.map { |x| GitFactory.expand_path(x) }
    remote_repository_path = GitFactory.init_bare(:remote)
    gitdocs_create(remote_repository_path, *full_destination_paths)
  end

  def gitdocs_assert_status_contains(*expected_outputs)
    command = gitdocs_command('status', '', Gitdocs::VERSION)
    expected_outputs.each do |expected_output|
      assert_partial_output(expected_output, output_from(command))
    end
  end

  def gitdocs_assert_status_not_contain(*not_expected_outputs)
    command = gitdocs_command('status', '', Gitdocs::VERSION)
    not_expected_outputs.each do |not_expected_output|
      assert_no_partial_output(not_expected_output, output_from(command))
    end
  end
end

class MiniTest::Spec
  include Helper
end
