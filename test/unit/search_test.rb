# -*- encoding : utf-8 -*-
require File.expand_path('../test_helper', __FILE__)

describe Gitdocs::Search do
  describe '.search' do
    subject { Gitdocs::Search.search(:term) }
    before do
      Gitdocs::Share.stubs(:all).returns([:share1, :share2])
      Gitdocs::Repository.stubs(:new).with(:share1).returns(:repository1)
      Gitdocs::Repository.stubs(:new).with(:share2).returns(:repository2)
      Gitdocs::Search
        .stubs(:new)
        .with([:repository1, :repository2])
        .returns(search = mock)
      search.stubs(:search).with(:term).returns(:result)
    end
    it { subject.must_equal(:result) }
  end

  describe 'initialize' do
    subject { Gitdocs::Search.new(:repositories) }
    it { subject.instance_variable_get(:@repositories).must_equal :repositories }
  end

  describe '#search' do
    subject { Gitdocs::Search.new([repository1, repository2]).search(term) }

    let(:repository1) { mock }
    let(:repository2) { mock }

    before do
      repository1.stubs(:root).returns('root')
      repository2.stubs(:root).returns('root')
    end

    describe 'term is missing' do
      let(:term) { nil }
      it { subject.must_equal({}) }
    end

    describe 'term is empty' do
      let(:term) { '' }
      it { subject.must_equal({}) }
    end

    describe 'term is non-empty' do
      let(:term) { 'term' }
      before do
        repository1.stubs(:grep).with(term).multiple_yields(
          %w(file1 context1)
        )
        repository2.stubs(:grep).with(term).multiple_yields(
          %w(file2 context2a),
          %w(file2 context2b),
          %w(file3 context3)
        )
      end

      it do
        subject.must_equal(
          Gitdocs::Search::RepoDescriptor.new('root', 0) => [
            Gitdocs::Search::SearchResult.new('file1', 'context1')
          ],
          Gitdocs::Search::RepoDescriptor.new('root', 1) => [
            Gitdocs::Search::SearchResult.new('file2', 'context2a ... context2b'),
            Gitdocs::Search::SearchResult.new('file3', 'context3')
          ]
        )
      end
    end
  end
end
