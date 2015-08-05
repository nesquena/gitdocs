module Gitdocs
  class Syncronizer
    include Celluloid

    # @param [Gitdocs::Share] share
    # @return [void]
    def commit_and_syncronize(share)
      repository = Repository.new(share)
      return unless repository.valid?
      repository.commit if share.sync_type == 'full'

      merge_result, push_result = Repository::Syncronizer.new(share).sync
      Notifier.sync_result(
        merge_result, push_result, root, share.notification
      )
      nil
    rescue => e
     # Rescue any standard exceptions which come from the push related
      # commands. This will prevent problems on a single share from killing
      # the entire daemon.
      Notifier.error(
        "Unexpected error syncing changes in #{share.path}",
       "#{e}",
        share.notification
      )
      nil
    end
  end
end
