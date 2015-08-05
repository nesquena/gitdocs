# -*- encoding : utf-8 -*-

require File.expand_path('../test_helper', __FILE__)

describe Gitdocs::Share do
  before do
    ShellTools.capture { Gitdocs::Initializer.initialize_database }
  end

  describe '.paths_to_sync' do
    subject { Gitdocs::Share.paths_to_sync }
    before do
      Gitdocs::Share.create_by_path!('/my/path')
      Gitdocs::Share.create_by_path!('/my/path2')
    end
    it { subject.must_equal(%w(/my/path /my/path2)) }
  end

  describe '.which_include' do
    subject { Gitdocs::Share.which_include(['/my/path1/stuff']) }
    before do
      Gitdocs::Share.create_by_path!('/my/path1')
      Gitdocs::Share.create_by_path!('/my/path2')
    end

    it { subject.map(&:path).must_equal(%w(/my/path1)) }
  end

  describe '.which_need_fetch' do
    subject { Gitdocs::Share.which_need_fetch }
    before do
      Gitdocs::Share.create_by_path!('/my/path1')
      Gitdocs::Share.create_by_path!('/my/path2')
    end

    it { subject.map(&:path).must_equal(%w(/my/path1 /my/path2)) }
  end

  describe '.create_by_path!' do
    subject { Gitdocs::Share.create_by_path!('/my/../my/path') }

    it { subject.must_equal(true) }

    describe 'side effects' do
      before { subject }
      it { assert_equal('/my/path', Gitdocs::Share.find(1).path) }
      it { assert_equal(15.0, Gitdocs::Share.find(1).polling_interval) }
    end
  end

  describe '.update_all' do
    before do
      Gitdocs::Share.create_by_path!('/my/path')
      Gitdocs::Share.create_by_path!('/my/path/2')
      Gitdocs::Share.create_by_path!('/my/path/3')
      Gitdocs::Share.create_by_path!('/my/path/4')
      Gitdocs::Share.create_by_path!('/my/path/5')

      Gitdocs::Share.update_all(
        '0' => { 'path' => '/my/path',    'polling_interval' => 42 },
        '1' => { 'path' => '/my/path/2',  'polling_interval' => 66 },
        '2' => { 'path' => '/my/path/3a', 'polling_interval' => 77 },
        '3' => { 'path' => '',            'polling_interval' => 88 },
        '4' => {                          'polling_interval' => 99 }
      )
    end
    it { Gitdocs::Share.all.size.must_equal(5) }
    it do
      Gitdocs::Share.all.map(&:path).must_equal(
        %w(/my/path /my/path/2 /my/path/3a /my/path/4 /my/path/5)
      )
    end
    it do
      Gitdocs::Share.all.map(&:polling_interval).must_equal(
        [42, 66, 77, 15, 15]
      )
    end
  end

  describe '.remove_by_id' do
    subject { Gitdocs::Share.remove_by_id(id) }

    before do
      Gitdocs::Share.create_by_path!('/my/path')
      Gitdocs::Share.create_by_path!('/my/path/2')
    end

    describe 'with existing id' do
      let(:id) { 2 }
      it { subject.must_equal(true) }

      describe 'side effects' do
        before { subject }
        it { assert_equal(%w(/my/path), Gitdocs::Share.all.map(&:path)) }
      end
    end

    describe 'with missing id' do
      let(:id) { 5 }
      it { subject.must_equal(false) }

      describe 'side effects' do
        before { subject }
        it { assert_equal(%w(/my/path /my/path/2), Gitdocs::Share.all.map(&:path)) }
      end
    end
  end

  describe '.remove_by_path' do
    subject { Gitdocs::Share.remove_by_path('/my/../my/path/2') }
    before do
      Gitdocs::Share.create_by_path!('/my/path')
      Gitdocs::Share.create_by_path!('/my/path/2')
      subject
    end
    it { assert_equal(%w(/my/path), Gitdocs::Share.all.map(&:path)) }
  end
end
