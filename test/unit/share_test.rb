# -*- encoding : utf-8 -*-

require File.expand_path('../test_helper', __FILE__)

describe Gitdocs::Share do
  before do
    ShellTools.capture { Gitdocs::Initializer.initialize_database }
  end

  describe '.paths' do
    before do
      Gitdocs::Share.create_by_path!('/my/path')
      Gitdocs::Share.create_by_path!('/my/path/2')
      Gitdocs::Share.create_by_path!('/my/path/3')
    end

    it { Gitdocs::Share.paths.must_equal(%w(/my/path /my/path/2 /my/path/3)) }
  end

  describe '.at' do
    subject { Gitdocs::Share.at(id) }
    before do
      Gitdocs::Share.create_by_path!('/my/path')
      Gitdocs::Share.create_by_path!('/my/path/2')
      Gitdocs::Share.create_by_path!('/my/path/3')
    end
    describe('present') { let(:id) { 1 } ; it { subject.path.must_equal('/my/path/2') } }
    describe('missing') { let(:id) { 3 } ; it { subject.must_equal(nil) } }
  end

  describe '.find_by_path' do
    before do
      Gitdocs::Share.create_by_path!('/my/path')
      Gitdocs::Share.create_by_path!('/my/path/2')
      Gitdocs::Share.create_by_path!('/my/path/3')
    end

    it 'finds a missing path' do
      Gitdocs::Share.find_by_path('/missing/path').must_be_nil
    end

    it 'finds a real path' do
      share = Gitdocs::Share.find_by_path('/my/path/2')
      share.wont_be_nil
      share.class.must_equal(Gitdocs::Share)
      share.path.must_equal('/my/path/2')
    end
  end

  describe '.create_by_path!' do
    describe 'defaults' do
      subject { Gitdocs::Share.create_by_path!('/my/../my/path') }
      before { subject }

      it { subject.persisted?.must_equal(true) }
      it { subject.path.must_equal('/my/path') }
      it { subject.polling_interval.must_equal(15.0) }
      it { subject.notification.must_equal(true) }
      it { subject.remote_name.must_equal('origin') }
      it { subject.branch_name.must_equal('master') }
      it { subject.sync_type.must_equal('full') }
    end

    describe 'override attributes' do
      subject do
        Gitdocs::Share.create_by_path!(
          '/my/../my/path', polling_interval: 5, notification: false
        )
      end

      it { subject.persisted?.must_equal(true) }
      it { subject.path.must_equal('/my/path') }
      it { subject.polling_interval.must_equal(5.0) }
      it { subject.notification.must_equal(false) }
      it { subject.remote_name.must_equal('origin') }
      it { subject.branch_name.must_equal('master') }
      it { subject.sync_type.must_equal('full') }
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

  describe '.remove_by_path' do
    it do
      Gitdocs::Share.create_by_path!('/my/path')
      Gitdocs::Share.create_by_path!('/my/path/2')
      Gitdocs::Share.remove_by_path('/my/../my/path/2')
      assert_equal ['/my/path'], Gitdocs::Share.all.map(&:path)
    end
  end

  describe '.remove_by_id' do
    it do
      Gitdocs::Share.create_by_path!('/my/path')
      Gitdocs::Share.create_by_path!('/my/path/2')

      # Delete an index which exists
      Gitdocs::Share.remove_by_id(2).must_equal(true) # normalized test
      assert_equal ['/my/path'], Gitdocs::Share.all.map(&:path)

      # Try to delete an index which does not exist
      Gitdocs::Share.remove_by_id(5).must_equal(false) # normalized test
      assert_equal ['/my/path'], Gitdocs::Share.all.map(&:path)
    end
  end
end
