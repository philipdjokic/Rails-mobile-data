class AppHotStore < HotStore
  class Unexpected < RuntimeError; end

  KEY_TYPE = 'app'.freeze

  @@APP_FIELDS_TO_DELETE = {
    "ios" => [ "first_seen_ads_date", "last_seen_ads_date", "has_ad_spend" ],
    "android" => [ "first_seen_ads_date", "last_seen_ads_date" ]
  }

  def initialize(redis_store: nil)
    super(redis_store: redis_store)

    @ad_attribution_sdks = nil

    @key_set = "app_keys"

    @required_fields = [ "app_identifier", "id", "platform" ]

    @platform_to_class = {
      "ios" => IosApp,
      "android" => AndroidApp
    }

    @fields_to_normalize = {
      "ios" => {
        "app_store_id" => "app_identifier",
        "has_in_app_purchases" => "in_app_purchases",
        "last_updated" => "current_version_release_date"
      },
      "android" => {
        "google_play_id" => "app_identifier",
        "released" => "current_version_release_date"
      }
    }
  end

  def ad_attribution_sdks
    @ad_attribution_sdks ||= {'ios' => Tag.find(24).ios_sdks.pluck(:id), 'android' => Tag.find(24).android_sdks.pluck(:id)}
  end

  def get_ad_attribution_sdks(platform, application_id)
    hs_data = read(platform, application_id)
    attribution_sdk_ids = ad_attribution_sdks[platform]
    hs_data['sdk_activity'].select {|sdk| attribution_sdk_ids.include?(sdk["id"]) and sdk['installed']}
  end

  def write(platform, app_ids, include_sdk_history: true)
    export_options = {:include_sdk_history => include_sdk_history}
    export_results = to_class(platform).bulk_export(ids: app_ids, options: export_options)
    export_results.each do |app_id, app_attributes|
      # Merge uninstalled_sdks and installed_sdks into sdk_activity
      if include_sdk_history
        sdk_activity = []
        app_attributes["installed_sdks"].each do |install_info|
          install_info["installed"] = true
          sdk_activity << install_info
        end
        app_attributes["uninstalled_sdks"].each do |install_info|
          install_info["installed"] = false
          sdk_activity << install_info
        end
        app_attributes["sdk_activity"] = sdk_activity
        app_attributes.delete("installed_sdks")
        app_attributes.delete("uninstalled_sdks")
      end

      delete_app_fields(platform, app_attributes)

      begin
        write_entry(KEY_TYPE, platform, app_id, app_attributes)
      rescue HotStore::MissingHotStoreField => e
        Bugsnag.notify(e)
      end
    end
  end

  def write_attribute(app_id, app_identifier, platform, attr_name, attr_value)
    raise Unexpected unless attr_name.is_a?(String)

    attributes = { attr_name => attr_value }

    # Add in required params to the app entry.
    attributes["id"] = app_id
    attributes["platform"] = platform
    attributes["app_identifier"] = app_identifier

    write_entry(KEY_TYPE, platform, app_id, attributes)
  end

  def write_ad_summary(app_id, app_identifier, platform, ad_summary)
    write_attribute(app_id, app_identifier, platform, 'ad_summaries', ad_summary)
  end

  def write_major_app(app_id,app_identifier, platform, major_app: true)
    write_attribute(app_id, app_identifier, platform, 'major_app', major_app)
  end

  def read(platform, app_id)
    read_entry(KEY_TYPE, platform, app_id)
  end

  def delete(platform, app_id)
    delete_entry(KEY_TYPE, platform, app_id)
  end

private

  def delete_app_fields(platform, app_attributes)
    @@APP_FIELDS_TO_DELETE[platform].each do |field|
      app_attributes.delete(field)
    end
  end

  def extra_app_fields(platform)
    if platform == "ios"
      return {
        :extra_from_app => [ "headquarters" ],
        :extra_sdk_fields => [ "activities" ]
      }
    else
      return {
        :extra_from_app => [ "headquarters" ],
        :extra_sdk_fields => [ "activities" ]
      }
    end
  end

end
