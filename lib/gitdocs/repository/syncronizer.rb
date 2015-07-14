# -*- encoding : utf-8 -*-
class Gitdocs::Repository::Syncronizer
  # @param [Gitdocs::Share] share
  def initialize(share)
    @share       = share
    @repository  = Gitdocs::Repository.new(share)
  end

  # @return [nil, StringArray<Object, Object>] merge and push result
  def sync
    # assert(@repository.valid?)
    @last_synced_revision = @repository.current_oid

    # Fetch ##################################################################
    fetch_result = @repository.fetch
    return [nil, nil] unless fetch_result == :ok
    return [nil, nil] if @share.sync_type == 'fetch'

    # Merge ##################################################################
    merge_result = @repository.merge
    merge_result = latest_author_count if merge_result == :ok
    return [merge_result, nil] if merge_result.is_a?(String)

    # Push ###################################################################
    push_result = @repository.push
    push_result = latest_author_count if push_result == :ok
    [merge_result, push_result]
  end

  ##########################################################################
  private

  # Update the author count for the last synced changes, and then update the
  # last synced revision id.
  #
  # @return [Hash<String,Int>]
  def latest_author_count
    last_oid = @last_synced_revision
    @last_synced_revision = @repository.current_oid

    @repository.author_count(last_oid)
  end
end
