class EwokScrapeWorker
  include Sidekiq::Worker

  sidekiq_options retry: false, queue: :sdk_live_scan

  RETRIES = 2

  def perform(method, *args)
    self.send(method.to_sym, *args)
  end

  def scrape_ios(app_identifier)
    tries ||= RETRIES + 1

    a = AppStoreService.attributes(app_identifier)
    raise AttributesBlank if a.blank?

    ios_app = IosApp.find_or_create_by!(app_identifier: app_identifier)
    ios_app_id = ios_app.id
    AppStoreSnapshotServiceWorker.new.perform(nil, ios_app_id)
    CreateDevelopersWorker.new.create_developers(ios_app_id, 'ios')
  rescue => e
    retry unless (tries -= 1).zero?
    raise e
  end

  def scrape_android(app_identifier)
    tries ||= RETRIES + 1

    a = GooglePlayService.attributes(app_identifier)
    raise AttributesBlank if a.blank?

    android_app = AndroidApp.create!(app_identifier: app_identifier)
    android_app_id = android_app.id
    GooglePlaySnapshotServiceWorker.new.perform(nil, android_app_id)
    CreateDevelopersWorker.new.create_developers(android_app_id, 'android')
  rescue => e
    retry unless (tries -= 1).zero?
    raise e
  end

  def scrape_ios_international(app_identifier)
    ios_app = IosApp.find_or_create_by!(app_identifier: app_identifier)

    ios_app_current_snapshot_job = IosAppCurrentSnapshotJob.create!(notes: "Ewok scrape ios app #{ios_app.id}: #{app_identifier}")

    if Rails.env.production?

      batch.jobs do
        AppStore.where(enabled: true).each do |app_store|
          AppStoreInternationalLiveSnapshotWorker.perform_async(
            ios_app_current_snapshot_job.id,
            [ios_app.id],
            app_store.id
          )
        end
      end
    else

      AppStore.where(enabled: true).each do |app_store|
        AppStoreInternationalLiveSnapshotWorker.new.perform(
          ios_app_current_snapshot_job.id,
          [ios_app.id],
          app_store.id
        )
      end
    end

  end

  class AttributesBlank< StandardError
    def initialize(message = "The attributes are blank.")
      super
    end
  end

  class << self

    def test
      return 'dont do this' if Rails.env.production?
      app_identifier = 389801252
      # IosApp.where(app_identifier: app_identifier).delete_all
      new.scrape_ios_international(app_identifier)
    end
  end
end
