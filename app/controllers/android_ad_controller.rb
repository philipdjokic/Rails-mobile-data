class AndroidAdController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_admin

  def create
    ad = AndroidAd.find_or_initialize_by(ad_id: params['ad_id'])

    ad.ad_type = params['ad_type'].to_sym
    ad.android_device_sn = params['android_device_sn']

    # Ad id is the s3 key prefix, where ad info is stored.
    ad.ad_id = params['ad_id']

    # Parse the time seen from the s3 url
    ad.date_seen = DateTime.parse(ad.ad_id[ad.ad_id.index('/') + 1, 19].sub('/', 'T'))
    ad.source_app = AndroidApp.find_by_app_identifier(params['source_app_identifier'])

    ad.advertised_app_identifier = params['advertised_app_identifier'].split('&')[0]
    ad.advertised_app = AndroidApp.find_or_create_by(app_identifier: ad.advertised_app_identifier)

    if ad.try(:advertised_app).newest_android_app_snapshot.nil?
        GooglePlaySnapshotLiveWorker.perform_async(nil, ad.advertised_app.id, true)
        AndroidMassScanService.run_by_ids([ad.advertised_app.id], use_batch: false)
    end

    ad.advertised_app.display_type = :normal
    ad.advertised_app.save!

    ad.google_account = params['google_account']
    ad.facebook_account = params['facebook_account']
    ad.ad_text = params['ad_text']

    ad.target_location = params['target_location']
    ad.target_max_age = params['target_max_age']
    ad.target_min_age = params['target_min_age']
    ad.target_similar_to_existing_users = params['target_similar_to_existing_users'].present?
    ad.target_gender = params['target_gender']
    ad.target_education = params['target_education']
    ad.target_existing_users = params['target_existing_users'].present?
    ad.target_facebook_audience = params['target_facebook_audience']
    ad.target_language = params['target_language']
    ad.target_relationship_status = params['target_relationship_status']
    if params['target_interests'].present?
      ad.target_interests = params['target_interests'].split('|')
    end
    ad.target_proximity_to_business = params['target_proximity_to_business']
    ad.save!
    imgs = []
    s3 = Aws::S3::Client.new
    begin
        puts s3.head_object({ bucket: "ms-android-automation-outputs",  key: "#{ad.ad_id}/screenshot.png"})
        imgs.append({
                "url" => "s3://ms-android-automation-outputs/#{ad.ad_id}/screenshot.png",
                "file_extension" => "png",
                "filename" => "screenshot.png"
            })
    rescue Aws::S3::Errors::NotFound
    end

    RedshiftLogger.new(records: [{
        id: "fb-#{ad.ad_id}",
        created_at: ad.date_seen,
        data_type: 'native',
        platform: 'android',
        ad_network: 'facebook',
        ad_format: 'facebook_news_feed',
        app_identifier: ad.advertised_app_identifier,
        publisher_app_identifier: 'com.facebook.katana',
        device_device_id: ad.android_device_sn,
        ad_network_config_identifier: "android-device-sn-#{ad.android_device_sn}",
        ad_text: ad.ad_text,
        images: imgs.to_json,
        }], table: 'mobile_ads').send!
    ElasticSearchWorker.new.perform(:index_android_apps, [ad.advertised_app.id])

    render json: { success: true }, status: 200
  end

end
