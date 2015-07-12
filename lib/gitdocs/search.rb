# -*- encoding : utf-8 -*-

module Gitdocs
  class Search
    RepoDescriptor = Struct.new(:name, :index)
    SearchResult   = Struct.new(:file, :context)

    # @param [String] term
    # @return (see #search)
    def self.search(term)
      new(Share.all.map { |x| Repository.new(x) }).search(term)
    end

    # @param [Array<Gitdocs::Repository>] repositories
    def initialize(repositories)
      @repositories = repositories
    end

    # @param [String] term
    # @return [Hash<RepoDescriptor, Array<SearchResult>>]
    def search(term)
      results = {}
      @repositories.each_with_index do |repository, index|
        descriptor = RepoDescriptor.new(repository.root, index)
        results[descriptor] = search_repository(repository, term)
      end
      results.delete_if { |_key, value| value.empty? }
    end

    private

    # @param [Repository] repository
    # @param [String] term
    # @return [Array<SearchResult>]
    def search_repository(repository, term)
      return [] if term.nil? || term.empty?

      results = []
      repository.grep(term) do |file, context|
        result = results.find { |s| s.file == file }
        if result
          result.context += ' ... ' + context
        else
          results << SearchResult.new(file, context)
        end
      end
      results
    end
  end
end
