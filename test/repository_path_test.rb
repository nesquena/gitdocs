# -*- encoding : utf-8 -*-
require File.expand_path('../test_helper', __FILE__)

describe Gitdocs::Repository::Path do
  let(:path) { Gitdocs::Repository::Path.new(repository, relative_path) }
  let(:repository) { stub(root: local_repo_path) }
  let(:local_repo_path) { 'tmp/unit/local' }

  let(:relative_path) { 'directory/file' }

  before do
    FileUtils.rm_rf('tmp/unit')
  end

  describe '#write' do
    subject { path.write('foobar', :message) }
    before { repository.expects(:write_commit_message).with(:message) }

    describe 'directory missing' do
      before { subject }
      it { local_file_content.must_equal "foobar\n" }
    end

    describe 'directory exists' do
      before do
        mkdir('directory')
        subject
      end
      it { local_file_content.must_equal "foobar\n" }
    end

    describe 'file exists' do
      before do
        write('directory/file', 'deadbeef')
        subject
      end
      it { local_file_content.must_equal "foobar\n" }
    end
  end

  describe '#touch' do
    subject { path.touch }

    describe 'when directory does not exist' do
      before { subject }
      it { local_file_content.must_equal '' }
    end

    describe 'when directory already exists' do
      before do
        mkdir('directory')
        subject
      end
      it { local_file_content.must_equal '' }
    end

    describe 'when file already exists' do
      before do
        write('directory/file', 'test')
        subject
      end
      it { local_file_content.must_equal 'test' }
    end
  end

  describe '#mkdir' do
    subject { path.mkdir }

    describe 'directory does not exist' do
      before { subject }
      it { File.directory?(File.join(local_repo_path, 'directory', 'file')) }
    end

    describe 'directory does exist' do
      before do
        mkdir('directory/file')
        subject
      end
      it { File.directory?(File.join(local_repo_path, 'directory', 'file')) }
    end

    describe 'already exists as a file' do
      before { write('directory/file', 'foobar') }
      it { assert_raises(Errno::EEXIST) { subject } }
    end
  end

  describe '#remove' do
    subject { path.remove }

    describe 'missing' do
      it { subject.must_be_nil }
    end

    describe 'directory' do
      before { mkdir('directory/file') }
      it { subject.must_be_nil }
    end

    describe 'file' do
      before do
        write('directory/file', 'foobar')
        subject
      end
      it { local_file_exist?.must_equal false }
    end
  end

  describe '#text?' do
    subject { path.text? }

    describe 'missing' do
      it { subject.must_equal false }
    end

    describe 'directory' do
      before { mkdir('directory/file') }
      it { subject.must_equal false }
    end

    describe 'not a text file' do
      let(:relative_path) { 'directory/file.png' }
      it { subject.must_equal false }
    end

    describe 'empty file' do
      before { write('directory/file', '') }
      it { subject.must_equal true }
    end

    describe 'text file' do
      before { write('directory/file', 'foobar') }
      it { subject.must_equal true }
    end
  end

  describe '#meta' do
    subject { path.meta }
    before do
      repository.stubs(:last_commit_for).with(relative_path).returns(commit)
    end

    describe 'when missing' do
      let(:commit)        { nil }
      it { assert_raises(RuntimeError) { subject } }
    end

    describe 'on a 'do
      let(:commit) { stub(author: { name: :name, time: :time } ) }
      before do
        write('directory0/file0', '')
        write('directory/file1', 'foo')
        write('directory/file2', 'bar')
      end

      describe 'file size 0' do
        let(:relative_path) { 'directory0/file0' }
        it { subject[:author].must_equal :name }
        it { subject[:size].must_equal(-1) }
        it { subject[:modified].must_equal :time }
      end

      describe 'file non-zero size' do
        let(:relative_path) { 'directory/file1' }
        it { subject[:author].must_equal :name }
        it { subject[:size].must_equal(3) }
        it { subject[:modified].must_equal :time }
      end

      describe 'directory size 0' do
        let(:relative_path) { 'directory0' }
        it { subject[:author].must_equal :name }
        it { subject[:size].must_equal(-1) }
        it { subject[:modified].must_equal :time }
      end

      describe 'directory non-zero size' do
        let(:relative_path) { 'directory' }
        it { subject[:author].must_equal :name }
        it { subject[:size].must_equal(6) }
        it { subject[:modified].must_equal :time }
      end
    end
  end

  describe '#exist?' do
    subject { path.exist? }

    describe 'missing' do
      it { subject.must_equal false }
    end

    describe 'directory' do
      before { mkdir('directory/file') }
      it { subject.must_equal true }
    end

    describe 'file' do
      before { write('directory/file', 'foobar') }
      it { subject.must_equal true }
    end
  end

  describe '#directory?' do
    subject { path.directory? }

    describe 'missing' do
      it { subject.must_equal false }
    end

    describe 'directory' do
      before { mkdir('directory/file') }
      it { subject.must_equal true }
    end

    describe 'file' do
      before { write('directory/file', 'foobar') }
      it { subject.must_equal false }
    end
  end

  describe '#absolute_path' do
    subject { path.absolute_path(ref) }

    describe 'no revision' do
      let(:ref) { nil }
      it { subject.must_equal absolute_local_path }
    end

    describe 'with revision' do
      let(:ref) { :ref }
      before { repository.stubs(:blob_at).with(relative_path, :ref).returns(blob) }

      describe 'no blob' do
        let(:blob) { nil }
        it { File.read(subject).must_equal "\n" }
      end

      describe 'has blob' do
        let(:blob) { stub(text: 'beef') }
        it { File.read(subject).must_equal "beef\n" }
      end
    end
  end

  describe '#readme_path' do
    subject { path.readme_path }

    describe 'no directory' do
      it { subject.must_be_nil }
    end

    describe 'no README' do
      before { mkdir('directory/file') }
      it { subject.must_be_nil }
    end

    describe 'with README.md' do
      before { write('directory/file/README.md', 'foobar') }
      it { subject.must_equal absolute_local_path('README.md') }
    end
  end

  describe '#file_listing' do
    subject { path.file_listing }

    describe 'missing' do
      it { subject.must_be_nil }
    end

    describe 'file' do
      before { write('directory/file', 'foobar') }
      it { subject.must_be_nil }
    end

    describe 'directory' do
      before do
        write('directory/file/.hidden', 'beef')
        mkdir('directory/file/dir1')
        write('directory/file/file1', 'foo')
        write('directory/file/file2', 'bar')

        # Paths which should not be included
        write('directory/file/.git', 'test')
        write('directory/file/.gitignore', 'test')
        write('directory/file/.gitmessage~', 'test')
      end

      it { subject.size.must_equal 4 }
      it { subject.map(&:name).must_equal %w(dir1 file1 file2 .hidden) }
      it { subject.map(&:is_directory).must_equal [true, false, false, false] }
    end
  end

  describe '#content' do
    subject { path.content }

    describe 'missing' do
      it { subject.must_be_nil }
    end

    describe 'directory' do
      before { mkdir('directory/file') }
      it { subject.must_be_nil }
    end

    describe 'file' do
      before { write('directory/file', 'foobar') }
      it { subject.must_equal 'foobar' }
    end
  end

  describe '#revisions' do
    subject { path.revisions }

    before do
      repository.stubs(:commits_for).returns([
        stub(oid: '1234567890', message: "short1\nlong", author: { name: :name1, time: :time1 } ),
        stub(oid: '0987654321', message: "short2\nlong", author: { name: :name2, time: :time2 } )
      ])
    end
    it { subject.size.must_equal(2) }
    it { subject[0].must_equal(commit: '1234567', subject: 'short1', author: :name1, date: :time1) }
    it { subject[1].must_equal(commit: '0987654', subject: 'short2', author: :name2, date: :time2) }
  end

  describe '#revert' do
    subject { path.revert('ref') }
    before { repository.expects(:blob_at).with(relative_path, 'ref').returns(blob) }

    describe 'blob missing' do
      let(:blob) { nil }
      it { subject.must_equal(nil) }
    end

    describe 'blob present' do
      let(:blob) { stub(text: 'deadbeef') }
      before { path.expects(:write).with('deadbeef', "Reverting '#{relative_path}' to ref") }
      it { subject }
    end
  end

  #############################################################################

  private

  def write(filename, content)
    mkdir(File.dirname(filename))
    File.write(File.join(local_repo_path, filename), content)
  end

  def mkdir(*path)
    FileUtils.mkdir_p(File.join(local_repo_path, *path))
  end

  def local_file_exist?
    File.exist?(File.join(local_repo_path, relative_path))
  end

  def local_file_content
    return nil unless local_file_exist?
    File.read(File.join(local_repo_path, relative_path))
  end

  def absolute_local_path(*path_elements)
    File.join(File.absolute_path(local_repo_path), relative_path, *path_elements)
  end
end
