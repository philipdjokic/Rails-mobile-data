# This is only meant to be used by the weekly scrape service (using the temporary proxies)
# For single/live scrapes, use the GooglePlaySnapshotLiveWorker
class GooglePlaySnapshotMassWorker
  include Sidekiq::Worker
  include GooglePlaySnapshotModule

  sidekiq_options queue: :google_play_snapshot_mass_worker, retry: false

  def perform(android_app_snapshot_job_id, android_app_id, create_developer = false)
    take_snapshot(
      android_app_snapshot_job_id,
      android_app_id,
      create_developer: create_developer,
      scrape_new_similar_apps: true,
      proxy_type: :temporary_proxies
    )
  end
end
