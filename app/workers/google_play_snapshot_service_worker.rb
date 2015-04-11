class GooglePlaySnapshotServiceWorker
  include Sidekiq::Worker

  # accounting for retries ourself, so disable sidekiq retries
  sidekiq_options retry: false

  MAX_TRIES = 3

  def perform(android_app_snapshot_job_id, android_app_id)

    save_attributes(android_app_id: android_app_id, android_app_snapshot_job_id: android_app_snapshot_job_id)

  end

  def save_attributes(options={})
    android_app = AndroidApp.find(options[:android_app_id])
    android_app_snapshot_job_id = options[:android_app_snapshot_job_id]

    s = AndroidAppSnapshot.create(android_app: android_app, android_app_snapshot_job_id: android_app_snapshot_job_id)

    try = 0

    begin

      a = GooglePlayService.attributes(android_app.app_identifier)

      raise 'GooglePlayService.attributes is empty' if a.empty?

      single_column_attributes = %w(
      name
      description
      price
      seller
      seller_url
      released
      size
      top_dev
      required_android_version
      version
      content_rating
      ratings_all_stars
      ratings_all_count
      in_app_purchases
      icon_url_300x300
      )

      single_column_attributes.each do |sca|
        value = a[sca.to_sym]
        s.send("#{sca}=", value) if value
      end

      # non single column
      # category
      # in_app_purchases_range
      # installs
      # similar_apps

      if category = a[:category]
        categories_snapshot_primary = AndroidAppCategoriesSnapshot.new
        categories_snapshot_primary.android_app_snapshot = s
        categories_snapshot_primary.android_app_category = AndroidAppCategory.find_or_create_by(name: category)
        categories_snapshot_primary.kind = :primary
        categories_snapshot_primary.save!
      end

      if iapr = a[:in_app_purchases_range]
        s.in_app_purchase_min = iapr.min
        s.in_app_purchase_max = iapr.max
      end
      

      if downloads = a[:downloads]
        s.downloads_min = downloads.min
        s.downloads_max = downloads.max
      end

      #don't get similar apps in development
      if !Rails.env.development?
        if similar_apps = a[:similar_apps]
          similar_apps.each do |app_identifier|

            android_app = AndroidApp.find_by_app_identifier(app_identifier)
            
            if android_app.nil?
              android_app = AndroidApp.new(app_identifier: app_identifier)
              success = android_app.save

              GooglePlaySnapshotServiceWorker.perform_async(android_app_snapshot_job_id, android_app.id) if success
            end

          end
        end
      end

    s.save!

    rescue => e
      ise = AndroidAppSnapshotException.create(android_app_snapshot: s, name: e.message, backtrace: e.backtrace, try: try, android_app_snapshot_job_id: android_app_snapshot_job_id)
      if (try += 1) < MAX_TRIES
        retry
      else
        s.status = :failure
        s.save!
      end
    else
      s.status = :success
      s.save!
    end

    s
  end

  def test_save_attributes
    ids = [389377362, 801207885, 509978909, 946286572, 355074115]

    android_app_ids = ids.map{ |id| AndroidApp.find_or_create_by(app_identifier: id) }

    perform(-1, ios_app_ids)
  end
  
end