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

Capybara.app_host          = 'http://localhost:7777/'
Capybara.default_driver    = :poltergeist
Capybara.run_server        = false
Capybara.default_wait_time = 20

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, timeout: 20)
end

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

  def before_setup
    super
    original = (ENV['PATH'] || '').split(File::PATH_SEPARATOR)
    set_env('PATH', ([File.expand_path('bin')] + original).join(File::PATH_SEPARATOR))
    FileUtils.rm_rf(current_dir)
  end

  def after_teardown
    super
    restore_env
    processes.clear
  end
end

module Helper
  include MiniTest::Aruba
  include Capybara::DSL
  include Capybara::RSpecMatchers

  def before_setup
    super
    set_env('HOME', abs_current_dir)
    ENV['TEST'] = nil
  end

  def teardown
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end

  def after_teardown
    super

    terminate_processes!
    prep_for_fs_check do
      next unless File.exist?('gitdocs.pid')

      pid = IO.read('gitdocs.pid').to_i
      Process.kill('KILL', pid)
      begin
        Process.wait(pid)
      rescue SystemCallError # rubocop:disable Lint/HandleExceptions
        # This means that the process is already gone.
        # Nothing to do.
      end
    end
  end

  def start_daemon
    Gitdocs::Initializer.initialize_database
    Gitdocs::Share.all.each do |share|
      share.update_attributes(polling_interval: 0.1, notification: false)
    end

    start_cmd = 'gitdocs start --pid=gitdocs.pid --port 7777'
    run(start_cmd, 15)
    assert_success(true)
    assert_partial_output('Started gitdocs', output_from(start_cmd))
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

  # @return [String] the absolute path for the repository
  def git_init_local(path = 'local')
    abs_path = abs_current_dir(path)
    Rugged::Repository.init_at(abs_path)
    abs_path
  end

  # @return [String] the absolute path for the repository
  def git_init_remote(path = 'remote')
    abs_path = abs_current_dir(path)
    Rugged::Repository.init_at(abs_path, :bare)
    abs_path
  end

  def wait_for_clean_workdir(path)
    dirty = true
    Timeout.timeout(20) do
      while dirty
        begin
          sleep(0.1)
          rugged = Rugged::Repository.new(abs_current_dir(path))
          dirty = !rugged.diff_workdir(rugged.head.target, include_untracked: true).deltas.empty?
        rescue Rugged::ReferenceError
          nil
        rescue Rugged::InvalidError
          nil
        rescue Rugged::RepositoryError
          nil
        end
      end
    end
  rescue Timeout::Error
    assert(false, "#{path} workdir is still dirty")
  end

  def wait_for_exact_file_content(file, exact_content)
    in_current_dir do
      begin
        Timeout.timeout(20) do
          sleep(0.1) until File.exist?(file) && IO.read(file) == exact_content
        end
      rescue Timeout::Error
        nil
      end

      assert(File.exist?(file), "Missing #{file}")
      actual_content = IO.read(file)
      assert(
        actual_content == exact_content,
        "Expected #{file} content: #{exact_content}\nActual content #{actual_content}"
      )
    end
  end

  def wait_for_directory(path)
    in_current_dir do
      begin
        Timeout.timeout(20) { sleep(0.1) until Dir.exist?(path) }
      rescue Timeout::Error
        nil
      end

      assert(Dir.exist?(path), "Missing #{path}")
    end
  end

  def wait_for_conflict_markers(path)
    in_current_dir do
      begin
        Timeout.timeout(20) { sleep(0.1) if File.exist?(path) }
      rescue Timeout::Error
        nil
      ensure
        assert(!File.exist?(path), "#{path} should have been removed")
      end

      begin
        Timeout.timeout(20) { sleep(0.1) if Dir.glob("#{path} (*)").empty? }
      rescue Timeout::Error
        nil
      ensure
        assert(!Dir.glob("#{path} (*)").empty?, "#{path} conflict marks should have been created")
      end
    end
  end

  def gitdocs_add(path = 'local')
    add_cmd = "gitdocs add #{path} --pid=gitdocs.pid"
    run_simple(add_cmd, true, 15)
    assert_success(true)
    assert_partial_output("Added path #{path} to doc list", output_from(add_cmd))
  end

  def git_clone_and_gitdocs_add(remote_path, *clone_paths)
    clone_paths.each do |clone_path|
      abs_clone_path = abs_current_dir(clone_path)
      FileUtils.rm_rf(abs_clone_path)
      repo = Rugged::Repository.clone_at(
        "file://#{remote_path}",
        abs_clone_path
      )
      repo.config['user.email'] = 'afish@example.com'
      repo.config['user.name']  = 'Art T. Fish'
      gitdocs_add(clone_path)
    end
  end

  def gitdocs_status
    @status_cmd = 'gitdocs status --pid=gitdocs.pid'
    run(@status_cmd, 15)
    assert_success(true)
  end

  def assert_gitdocs_status_contains(expected)
    assert_partial_output(expected, output_from(@status_cmd))
  end

  def assert_gitdocs_status_not_contain(expected)
    assert_no_partial_output(expected, output_from(@status_cmd))
  end
end

class MiniTest::Spec
  include Helper
end
