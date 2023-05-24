class SyncIssuesWorker
  include Sidekiq::Worker
  sidekiq_options lock: :until_executed

  def perform(registry_id, id)
    Package.where(registry_id: registry_id).find(id).try(:sync_issues)
  end
end