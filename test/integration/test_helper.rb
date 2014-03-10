require 'rubygems'
require 'minitest/autorun'
$LOAD_PATH.unshift File.expand_path('../../lib')
require 'gitdocs'
require 'aruba'
require 'aruba/api'

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

  def before_setup
    super
    set_env('HOME', abs_current_dir)
    ENV['TEST'] = nil
  end

  def after_teardown
    super

    terminate_processes!
    prep_for_fs_check do
      next unless File.exists?('gitdocs.pid')

      pid = IO.read('gitdocs.pid').to_i
      Process.kill('KILL', pid)
      begin
        Process.wait(pid)
      rescue SystemCallError
        # This means that the process is already gone.
        # Nothing to do.
      end
    end
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

  def gitdocs_add(path = 'local')
    add_cmd = "gitdocs add #{path} --pid=gitdocs.pid"
    run_simple(add_cmd, true, 15)
    assert_success(true)
    assert_partial_output("Added path #{path} to doc list", output_from(add_cmd))
  end

  def git_clone_and_gitdocs_add(remote_path, *clone_paths)
    clone_paths.each do |clone_path|
      repo = Rugged::Repository.clone_at(
        "file://#{remote_path}",
        abs_current_dir(clone_path)
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
