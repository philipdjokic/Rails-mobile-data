class AdDataAccessor
  MAX_PAGE_SIZE = 20000

  def initialize
    @delegate = RedshiftAdDataAccessor.new
    @thumbnail_service = ThumbnailService.new
  end

  def has_ad_spend_data(
    account,
    app,
    source_ids: nil
    )
    if source_ids.nil?
        source_ids = account.available_ad_sources.values.map {|x| x[:id]}
    end
    source_ids = account.restrict_ad_sources(source_ids)

    @delegate.has_ad_spend_data(
      app.app_identifier.to_s,
      app.platform,
      source_ids: source_ids
    )
  end

  def fetch_all_app_summaries(
    account,
    page_size: 20,
    page_number:0
    )
    # The account must have access to all ad sources to use this api.
    all_source_ids = account.available_ad_sources.values.map {|x| x[:id]}
    raise "Unauthorized" if (all_source_ids - account.restrict_ad_sources(all_source_ids)).any?

    results, full_count = @delegate.fetch_all_app_summaries(
      page_size: page_size,
      page_number: page_number
    )

    grouped_results = Hash.new{{
        "ad_networks" => [],
        "creative_formats" =>  Set.new,
        "first_seen_ads_date" => nil,
        "last_seen_ads_date" => nil,
        "number_of_creatives" => 0
        }}

    # Build the app_identifier => id map for each of the results.
    # Optimized into two queries (one for IosApp and AndroidApp).
    app_identifier_to_id = {}
    ["ios", "android"].each do |platform|
      platform_results = results.select { |result| result["platform"] == platform }
      platform_app_identifiers = platform_results.map { |platform_result| platform_result["app_identifier"] }
      next if platform_app_identifiers.empty?
      platform_map = "#{platform}_app".classify.constantize.where(:app_identifier => platform_app_identifiers).pluck(:id, :app_identifier)
      platform_map.each do |app|
        app_identifier_to_id[app[1].to_s] = app[0] if app[0] and app[1]
      end
    end

    results.each do |result|
      id = app_identifier_to_id[result["app_identifier"]]
      app_record = grouped_results[id]
      grouped_results[id] = app_record
      app_record['app_identifier'] = result["app_identifier"]
      app_record['platform'] = result["platform"]
      app_record['ad_networks'].append(
      {
          "id" => result['ad_network'],
          "name" => AdDataPermissions::AD_DATA_NETWORK_ID_TO_NAME[result['ad_network']],
          "ad_formats" => _process_ad_formats(result['ad_formats']),
          "creative_formats" => result['creative_formats'] ? result['creative_formats'].split(',').uniq : [],
          "number_of_creatives" => result['number_of_creatives'] ? result['number_of_creatives'] : 0,
          "first_seen_ads_date" => result['first_seen_ads_date'],
          "last_seen_ads_date" => result['last_seen_ads_date']
      })
    end

    return grouped_results, full_count
  end

  def fetch_app_summaries(
    account,
    apps,
    platform,
    source_ids: nil
    )
    if apps == [] || source_ids == []
        return [], 0
    end
    if source_ids.nil?
    source_ids = account.available_ad_sources.values.map {|x| x[:id]}
    end
    source_ids = account.restrict_ad_sources(source_ids)
    if ! AdDataPermissions::APP_PLATFORMS.include? platform
      raise "Unsupported platform"
    end

    results = @delegate.fetch_app_summaries(
      apps.map {|app| app.app_identifier.to_s},
      platform,
      source_ids: source_ids
    )
    grouped_results = Hash.new{{
        "ad_networks" => [],
        "creative_formats" =>  Set.new,
        "first_seen_ads_date" => nil,
        "last_seen_ads_date" => nil,
        "ad_attribution_sdks" => nil, # Fill in later
        "number_of_creatives" => 0
        }}

    app_id_to_apps = apps.map {|app| [app.app_identifier.to_s, app.id]}.to_h
    results.each do |result|
        id = app_id_to_apps[result['app_identifier']]
        app_record = grouped_results[id]
        grouped_results[id] = app_record
        app_record['ad_networks'].append(
        {
            "id" => result['ad_network'],
            "name" => AdDataPermissions::AD_DATA_NETWORK_ID_TO_NAME[result['ad_network']],
            "ad_formats" => _process_ad_formats(result['ad_formats']),
            "creative_formats" => result['creative_formats'] ? result['creative_formats'].split(',').uniq : [],
            "number_of_creatives" => result['number_of_creatives'] ? result['number_of_creatives'] : 0,
            "first_seen_ads_date" => result['first_seen_ads_date'],
            "last_seen_ads_date" => result['last_seen_ads_date']
            })

        app_record["number_of_creatives"] += result['number_of_creatives'] ? result['number_of_creatives'] : 0

        if ! result['creative_formats'].nil?
            result['creative_formats'].split(',').each { |x| app_record['creative_formats'].add(x) }
        end

        if app_record['first_seen_ads_date'].nil? or result['first_seen_ads_date'] <= app_record['first_seen_ads_date']
            app_record['first_seen_ads_date'] = result['first_seen_ads_date']
        end

        if app_record['last_seen_ads_date'].nil? or result['last_seen_ads_date'] >= app_record['last_seen_ads_date']
            app_record['last_seen_ads_date'] = result['last_seen_ads_date']
        end
    end

    app_model = "#{platform}_app".classify.constantize

    grouped_results.each do |app_id, record|
        app = app_model.find(app_id)
        record['ad_attribution_sdks'] = app.ad_attribution_sdks
        record['icon'] = app.icon_url
        record['name'] = app.name
        record['type'] = app.class.name
        record['last_scanned'] = app.last_scanned
    end

    grouped_results
  end

  def fetch_creatives(
    account,
    apps,
    platform,
    source_ids: nil,
    formats: nil,
    first_seen_creative_date: nil,
    last_seen_creative_date: nil,
    sort_by: 'first_seen_creative_date',
    order_by: 'desc',
    page_size: 20,
    page_number:0,
    force_cache: false,
    group_by_app_id: true)
    # Fetch creatives for apps return format is below:
    # [
    #   {
    #     "86": {
    #       "creatives": [
    #         {
    #           "first_seen_creative_date": "2017-07-27T13:22:23.000+00:00",
    #           "last_seen_creative_date": "2017-07-27T13:22:23.000+00:00",
    #           "app_identifier": "com.ubercab",
    #           "ad_network": "facebook",
    #           "platform": "android",
    #           "url": "[some url]",
    #           "count": 1,
    #           "suffix": "png",
    #           "type": "image" => Us this to determine how to render.
    #         },
    #         ...
    #       ],
    #       "full_count": 4 => number of creatives for app 86
    #     }
    #   },
    #   46 => Number of total creatives available.
    # ]
    if apps == [] || formats == [] || source_ids == []
        if group_by_app_id
            return {}, 0
        else
            return [], 0
        end
    end

    page_size = [page_size.to_i, MAX_PAGE_SIZE].min
    page_number = [page_number.to_i, 0].max
    if source_ids.nil?
    source_ids = account.available_ad_sources.values.map {|x| x[:id]}
    end
    source_ids = account.restrict_ad_sources(source_ids)
    if ! AdDataPermissions::APP_PLATFORMS.include? platform
      raise "Unsupported platform"
    end

    creatives, full_count = @delegate.fetch_creatives(
      apps.map {|app| app.app_identifier.to_s},
      platform,
      source_ids: source_ids,
      formats: formats,
      first_seen_creative_date: first_seen_creative_date,
      last_seen_creative_date: last_seen_creative_date,
      sort_by: sort_by,
      order_by: order_by,
      page_size: page_size,
      page_number:page_number
    )

    signer_options = {}
    if ENV['AWS_PRESIGNER_ACCESS_KEY_ID']
        signer_options[:client] = Aws::S3::Client.new(
          access_key_id: ENV['AWS_PRESIGNER_ACCESS_KEY_ID'],
          secret_access_key: ENV['AWS_PRESIGNER_SECRET_ACCESS_KEY']
        )
    end
    signer = Aws::S3::Presigner.new(signer_options)

    grouped_creatives = Hash.new{{"creatives" => [], "count" => 0}}
    app_id_to_apps = apps.map {|app| [app.app_identifier.to_s, app.id]}.to_h

    creatives.each do |creative|
        parsed_url = URI.parse(creative['url'])
        if parsed_url.scheme == 's3'
            # Expose S3 assets by creating presigned urls.
            # Cache these so we don't hit the AWS API every request.
            get_url_key = "AdDataAccessor:fetch_creatives:s3_get_key#{Digest::SHA1.hexdigest(creative['url'])}"
            new_url = Rails.cache.fetch(get_url_key, expires_in: 6.days, force: force_cache) do
                params = {
                    bucket: parsed_url.host,
                    key: parsed_url.path[1..-1],
                    expires_in: 1.weeks
                }
                if ['html', 'playable'].include? creative['format']
                    creative['content-type'] = 'set'
                    params[:response_content_type] = 'text/html'
                end
                signer.presigned_url(
                    :get_object,
                    params
                    )
            end

            creative['url'] = new_url
        end
        if ['html', 'playable'].include? creative['format']
            creative['thumbnail'] = @thumbnail_service.screenshot_url(
                creative['url'],
                width: "250",
                format: "png",
                delay: "1")
        end
        creative['suffix'] = parsed_url.path.split('.')[-1].downcase

        # Temp wrap the ad network as a list and call it ad_networks.
        # TODO properly aggregate creatives across ad networks.
        # needs backend support for fuzzy matching videos,fb ad text, etc..
        creative['ad_networks'] = [{"id" => creative['ad_network'], "name" => AdDataPermissions::AD_DATA_NETWORK_ID_TO_NAME[creative['ad_network']]}]
        creative.delete('ad_network')

        # Need to actually set the default value back to the original key.
        group = grouped_creatives[app_id_to_apps[creative['app_identifier']]]
        grouped_creatives[app_id_to_apps[creative['app_identifier']]] = group
        creative['app_id'] = app_id_to_apps[creative['app_identifier']]
        group['creatives']  += [creative]
        group['count']  += 1
    end
    if group_by_app_id
        return grouped_creatives, full_count
    else
        return creatives, full_count
    end
  end


  def raw_query(
    account,
    platforms:['ios', 'android'],
    source_ids: nil,
    first_seen_ads_date: nil,
    last_seen_ads_date: nil,
    sort_by: 'first_seen_ads_date',
    order_by: 'desc',
    page_size: 20,
    page_number:0,
    extra_fields:[])
    if platforms == [] || source_ids == []
        return [], 0
    end
    page_size = [page_size.to_i, MAX_PAGE_SIZE].min
    page_number = [page_number.to_i, 0].max
    visible_source_ids = account.available_ad_sources.values.map {|x| x[:id]}
    if source_ids.nil?
      source_ids = visible_source_ids
    end
    source_ids = account.restrict_ad_sources(source_ids)
    platforms = platforms.select {|x| AdDataPermissions::APP_PLATFORMS.include? x}

    results, full_count = @delegate.query(
      platforms:platforms,
      source_ids: source_ids,
      visible_source_ids: visible_source_ids,
      first_seen_ads_date: first_seen_ads_date,
      last_seen_ads_date: last_seen_ads_date,
      sort_by: sort_by,
      order_by: order_by,
      page_size: page_size,
      page_number:page_number,
      extra_fields:extra_fields
    )
    results = results.map do |app|
      app['ad_formats'] = _process_ad_formats(app['ad_formats'])
      app['ad_sources'] = app['ad_networks'].split(',').map {|network_id| {"id" => network_id, "name" => AdDataPermissions::AD_DATA_NETWORK_ID_TO_NAME[network_id]}}
      app.delete('ad_networks')
      app
    end
    return results, full_count
  end



  def query(
    account,
    platforms:['ios', 'android'],
    source_ids: nil,
    first_seen_ads_date: nil,
    last_seen_ads_date: nil,
    sort_by: 'first_seen_ads_date',
    order_by: 'desc',
    page_size: 20,
    page_number:0,
    extra_fields:[])
    # Filters and sorts apps by ad intel data.
    # Params:
    #   account: The account with which to scope the query by (some accounts can access a subset of data).
    #   platforms: The platforms to filter this query by.
    #   sort_by: A field to sort the result set by one of first_seen_ads_date, last_seen_ads_date or user_base_display_score.
    #   order_by: Order by asc or desc,
    #   source_ids: A list of source_ids from available_sources to which this query applies to nil => all supported.
    # Returns:
    # [
    #     {
    #         "id": 215,
    #         "platform": "android",
    #         "categories": [
    #             {
    #                 "name": "Weather",
    #                 "id": "WEATHER"
    #             }
    #         ],
    #         "user_base_display_score": 0,
    #         "user_base_name": "elite",
    #         "icon": "//lh3.googleusercontent.com/nIenkMvx3o8AcWeqoT9BQwBNLAxSy_DwmcdgUCMx4K9P65aqhzpQHJbmVDHsvUIqkmM=w300",
    #         "publisher": {
    #             "name": "MACHAPP Software Ltd",
    #             "id": 243
    #         },
    #         "first_seen_ads_date": "2017-09-11T19:49:51.000-07:00",
    #         "first_seen_ads_days": 42,
    #         "last_seen_ads_date": "2017-09-11T21:26:32.000-07:00",
    #         "last_seen_ads_days": 42,
    #         "ad_attribution_sdks": [],
    #         "ad_sources" : ['facebook']
    #     },
    #     {
    #         "id": 3310094,
    #         "platform": "ios",
    #         "categories": [
    #             {
    #                 "name": "Games",
    #                 "type": "primary",
    #                 "id": "Games"
    #             }
    #             ...
    #         ],
    #         "user_base_display_score": 33,
    #         "user_base_name": "weak",
    #         "user_bases": [
    #             {
    #                 "country_code": "US",
    #                 "user_base": "weak",
    #                 "country": "United States",
    #                 "score": 33
    #             },
    #             ...
    #         ],
    #         "icon": "https://is4-ssl.mzstatic.com/image/thumb/Purple127/v4/cd/b9/d5/cdb9d599-ae5f-5e32-c344-69c640fdc448/source/100x100bb.jpg",
    #         "publisher": {
    #             "name": "Waranthorn Chaikhamruang",
    #             "id": 516072
    #         },
    #         "first_seen_ads_date": "2017-10-23T08:09:22.000-07:00",
    #         "first_seen_ads_days": 0,
    #         "last_seen_ads_date": "2017-10-23T08:09:22.000-07:00",
    #         "last_seen_ads_days": 0,
    #         "ad_attribution_sdks": [],
    #         "ad_sources" : ['facebook']
    #     },
    # ]
    results, full_count = raw_query(
        account,
        platforms:platforms,
        source_ids: source_ids,
        first_seen_ads_date: first_seen_ads_date,
        last_seen_ads_date: last_seen_ads_date,
        sort_by: sort_by,
        order_by: order_by,
        page_size: page_size,
        page_number:page_number,
        extra_fields:extra_fields
        )

    output = []

    results.each do |app|
      app_model = "#{app['platform']}_app".classify.constantize.find_by_app_identifier(app['app_identifier'])
      if app_model.nil?
        next
      end

      # Skip apps for which we have no data.
      if app['platform'] == 'ios'
        if  app_model.first_international_snapshot.empty?
          next
        end
        snap_accessor = IosSnapshotAccessor.new
        categories = snap_accessor.categories_from_ios_app(app_model).map do |x|
          x['id'] = x['name']
          x
        end
        app_available = app_model.app_store_available
        user_bases = app_model.scored_user_bases
      elsif app['platform'] == 'android'
        if app_model.newest_android_app_snapshot.nil?
          next
        end
        app_available = app_model.app_available?

        categories = app_model.android_app_snapshot_categories
        user_bases = {}
      end
      publisher = app_model.send("#{app['platform']}_developer".to_sym)
      app = app.merge(
        {
        'id' => app_model.id,
        'name' =>  app_model.name,
        'last_scanned' =>  app_model.last_scanned,
        'app_available' => app_available,
        'categories' => categories,
        'user_bases' =>  user_bases,
        'user_base' => app_model.user_base,
        'icon' => app_model.icon_url,
        'publisher' =>  publisher ? {"id" => publisher.id, "name" => publisher.name} : {},
        'ad_attribution_sdks' => app_model.ad_attribution_sdks,
        'type' => app_model.class.name
        }
      )
      output.append(app)
    end
    return output, full_count
  end

  def _process_ad_formats(ad_formats)
    Set.new(ad_formats.split(',')).to_a.map{|x| {"id" => x, "name" => x.split('_').map{|x| x.capitalize}.join(" ")}}
  end
end
