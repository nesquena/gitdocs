# -*- encoding : utf-8 -*-

require File.expand_path('../test_helper', __FILE__)

describe Gitdocs::Repository::Syncronizer do
  let(:syncronizer) { Gitdocs::Repository::Syncronizer.new(share) }
  let(:share)      { stub(sync_type: sync_type) }
  let(:repository) { stub }
  before do
    Gitdocs::Repository.stubs(:new).with(share).returns(repository)
  end

  describe '#sync' do
    subject { syncronizer.sync }

    before do
      repository.stubs(:current_oid).returns(*current_oids)
      repository.expects(:fetch).returns(fetch_result)
    end

    describe 'fetch sync_type' do
      let(:sync_type)    { 'fetch' }
      let(:current_oids) { [:oid1] }

      describe 'fetch fails' do
        let(:fetch_result) { 'error' }
        it { subject.must_equal([nil, nil]) }
      end

      describe 'fetch succeeds' do
        let(:fetch_result) { :ok }
        it { subject.must_equal([nil, nil]) }
      end
    end

    describe 'full sync_type' do
      let(:sync_type) { 'full' }

      describe 'fetch error' do
        let(:current_oids) { [:oid1] }
        let(:fetch_result) { 'error' }
        it { subject.must_equal([nil, nil]) }
      end

      describe 'merge' do
        let(:fetch_result) { :ok }
        before { repository.expects(:merge).returns(merge_result) }

        describe 'error' do
          let(:current_oids) { [:oid1] }
          let(:merge_result) { 'merge failed' }
          it { subject.must_equal(['merge failed', nil]) }
        end

        describe 'conflict and push error' do
          let(:current_oids) { [:oid1] }
          let(:merge_result) { :merge_result }
          before { repository.expects(:push).returns(:push_error) }

          it { subject.must_equal([:merge_result, :push_error]) }
        end

        describe 'ok and push ok' do
          let(:current_oids) { [:oid1, :oid2] }
          let(:merge_result) { :ok }
          before do
            repository.expects(:author_count).with(:oid1).returns(:merge_count)
            repository.expects(:push).returns(:ok)
            repository.expects(:author_count).with(:oid2).returns(:push_count)
          end
          it { subject.must_equal([:merge_count, :push_count]) }
        end
      end
    end
  end
end
