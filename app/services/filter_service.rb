class FilterService
  class << self
  
    # @author Shane Wey
    def filter_companies(company_filters)
      company_results  = Company
      company_results = company_results.where("fortune_1000_rank <= ?", company_filters['fortuneRank'].to_i) if company_filters['fortuneRank']
      # company_results = company_results.where("funding >= ?", company_filters[:funding]) if company_filters[:funding]
      # company_results = company_results.where(country: company_filters[:country]) if company_filters[:country]
      company_results
    end
    
    # @author Shane Wey
    def company_ios_apps_query(company_filters)
      query = []
      
      if fortune_rank_s = company_filters['fortuneRank']
        fortune_rank = fortune_rank_s.to_i  #convert to i for safety
        query << "joins(ios_apps_websites: {website: :company}).where('companies.fortune_1000_rank <= ?', #{fortune_rank})"
      end
      
      query
    end
    
    # @author Jason Lew
    def company_android_apps_query(company_filters)
      query = []
      
      if fortune_rank_s = company_filters['fortuneRank']
        fortune_rank = fortune_rank_s.to_i  #convert to i for safety
        query << "joins(android_apps_websites: {website: :company}).where('companies.fortune_1000_rank <= ?', #{fortune_rank})"
      end
      
      query
    end
    
    def ios_apps_query(app_filters)
      queries = []

      if app_filters['mobilePriority']
        mobile_priorities = []
        mobile_priorities << IosApp.mobile_priorities[:high] if app_filters['mobilePriority'].include?("H")
        mobile_priorities << IosApp.mobile_priorities[:medium] if app_filters['mobilePriority'].include?("M")
        mobile_priorities << IosApp.mobile_priorities[:low] if app_filters['mobilePriority'].include?("L")
        queries << "where(mobile_priority: #{mobile_priorities})"
      end
      
      queries << 'joins(:ios_fb_ad_appearances)' if app_filters['oldAdSpend']
      queries << 'joins(:ios_fb_ads)' if app_filters['adSpend']
      
      if app_filters['userBases']
        user_bases = []
        user_bases << IosApp.user_bases[:elite] if app_filters['userBases'].include?("elite")
        user_bases << IosApp.user_bases[:strong] if app_filters['userBases'].include?("strong")
        user_bases << IosApp.user_bases[:moderate] if app_filters['userBases'].include?("moderate")
        user_bases << IosApp.user_bases[:weak] if app_filters['userBases'].include?("weak")
        queries << "where(user_base: #{user_bases})"
      end
      
      if app_filters['updatedDaysAgo']
        queries << "joins(:newest_ios_app_snapshot).where('ios_app_snapshots.released > ?', \"#{app_filters['updatedDaysAgo'].to_i.days.ago.to_date}\")"
      end
      
      if app_filters['categories']
        cats = app_filters['categories'] #.map{|c| "\"#{c}\""}

        if cats.include?("Kids")  # workaround for Kids categories, which are technically secondary but show up as primary
          queries << "joins(newest_ios_app_snapshot: {ios_app_categories_snapshots: :ios_app_category}).where('ios_app_categories.name IN (?)', #{cats})"
        else
          queries << "joins(newest_ios_app_snapshot: {ios_app_categories_snapshots: :ios_app_category}).where('ios_app_categories.name IN (?) AND ios_app_categories_snapshots.kind = ?', #{cats}, #{IosAppCategoriesSnapshot.kinds[:primary]})"
        end

        
      end

      if app_filters['supportDesk']
        for support_desk in app_filters['supportDesk']
          queries << "joins(:newest_ios_app_snapshot).where('ios_app_snapshots.support_url LIKE \"%.#{support_desk}.%\"')"
        end
      end

      if app_filters['sdkNames']

        apps_with_sdk = []
        sdk_ids = app_filters['sdkNames'].map{ |x| x['id'].to_i }

        IosSdk.find(sdk_ids).each { |sdk| apps_with_sdk << sdk.get_current_apps }

        if app_filters['sdkOperator'] && app_filters['sdkOperator'].include?("and") && sdk_ids.count > 1
          apps_with_sdk = apps_with_sdk.inject(:&)
        end

        apps_with_sdk = apps_with_sdk.flatten.map {|app| app.id if app }.compact.uniq # create array of unique AR objects & map to ids

        if sdk_ids.present? 
          if app_filters['sdkOperator'] && app_filters['sdkOperator'].include?("not")
            queries << "where.not(id: #{apps_with_sdk}).joins(:ipa_snapshots).where('ipa_snapshots.scan_status' => #{IpaSnapshot.scan_statuses[:scanned]})" 
          else
            queries << "where(id: #{apps_with_sdk})"
          end
        end
      end

      queries
    end
    
    def android_apps_query(app_filters)
      queries = []

      if app_filters['mobilePriority']
        mobile_priorities = []
        mobile_priorities << AndroidApp.mobile_priorities[:high] if app_filters['mobilePriority'].include?("H")
        mobile_priorities << AndroidApp.mobile_priorities[:medium] if app_filters['mobilePriority'].include?("M")
        mobile_priorities << AndroidApp.mobile_priorities[:low] if app_filters['mobilePriority'].include?("L")
        queries << "where(mobile_priority: #{mobile_priorities})"
      end
      
      queries << 'joins(:android_fb_ad_appearances)' if app_filters['oldAdSpend']
      
      if app_filters['userBases']
        user_bases = []
        user_bases << AndroidApp.user_bases[:elite] if app_filters['userBases'].include?("elite")
        user_bases << AndroidApp.user_bases[:strong] if app_filters['userBases'].include?("strong")
        user_bases << AndroidApp.user_bases[:moderate] if app_filters['userBases'].include?("moderate")
        user_bases << AndroidApp.user_bases[:weak] if app_filters['userBases'].include?("weak")
        queries << "where(user_base: #{user_bases})"
      end
      
      if app_filters['updatedDaysAgo']
        queries << "joins(:newest_android_app_snapshot).where('android_app_snapshots.released > ?', \"#{app_filters['updatedDaysAgo'].to_i.days.ago.to_date}\")"
      end
      
      if app_filters['categories']
        gaming_categories = [
          'Action',
          'Adventure',
          'Arcade',
          'Board',
          'Card',
          'Casino',
          'Casual',
          'Educational',
          'Music',
          'Puzzle',
          'Racing',
          'Role Playing',
          'Simulation',
          'Sports',
          'Strategy',
          'Trivia',
          'Word'
        ]
        family_categories = [
          'Action & Adventure',
          'Brain Games',
          'Creativity',
          'Education',
          'Music & Video',
          'Pretend Play'
        ]
        categories = app_filters['categories'] #.map{|c| "\"#{c}\""}
        categories.each do |category|
          if category == 'Games'
            categories += gaming_categories
          end
          if category == 'Family'
            categories += family_categories
          end
        end
        li categories
        li categories.join(',')
        queries << "joins(newest_android_app_snapshot: {android_app_categories_snapshots: :android_app_category}).where('android_app_categories.name IN (?)', #{categories})"
      end

      if app_filters['downloads']

        # Download Value Ranges - broken up to intervals of scraped data
        download_min_values = [
            [1, 5, 10, 50, 100, 500, 1000, 5000, 10000],  # 0 - 50K
            [50000, 100000],                              # 50K - 500K
            [500000, 1000000, 5000000],                   # 500K - 10M
            [10000000, 50000000],                         # 10M - 100M
            [100000000, 500000000],                       # 100M - 1B
            [1000000000]                                  # 1B - 5B
        ]
        download_ids = app_filters['downloads'].map{|x| x['id'].to_i}

        filter_values_array = []

        download_ids.each do |id|
          filter_values_array.push(*download_min_values[id])
        end

        queries << "where('android_app_snapshots.downloads_min IN (?)', #{filter_values_array})"
      end

      if app_filters['sdkNames']

        apps_with_sdk = []
        sdk_ids = app_filters['sdkNames'].map{|x| x['id'].to_i}

        android_sdks = AndroidSdk.find(sdk_ids)
        android_sdks.each{|sdk| apps_with_sdk << sdk.get_current_apps}
        apps_with_sdk = apps_with_sdk.inject(:&) if app_filters['sdkOperator'] && app_filters['sdkOperator'].include?("and") && sdk_ids.count > 1
        apps_with_sdk.flatten! # combines all arrays together
        apps_with_sdk = apps_with_sdk.uniq{ |app| app.id }.map{ |app| app.id } # create array of unique AR objects & map to ids

        if sdk_ids.present? 
          if app_filters['sdkOperator'] && app_filters['sdkOperator'].include?("not")
            queries << "where.not(id: #{apps_with_sdk}).joins(:apk_snapshots).where('apk_snapshots.scan_status' => #{ApkSnapshot.scan_statuses[:scan_success]})" 
          else
            queries << "where(id: #{apps_with_sdk})"
          end
        end
      end

      queries
    end
    
    def filter_ios_apps(app_filters: nil, company_filters: nil, custom_keywords: nil, page_size: 50, page_num: 1, sort_by: 'appName', order_by: 'ASC')
      
      # individual parts of the giant query which will be executed at the end
      # all elements of the array will be chained together
      parts = []
      
      parts << "includes(:ios_developer, :ios_fb_ad_appearances, newest_ios_app_snapshot: :ios_app_categories, websites: :company).joins(:newest_ios_app_snapshot).where('ios_app_snapshots.name IS NOT null')"

      parts << ios_app_keywords_query(custom_keywords) if custom_keywords.present?
      
      if company_filters.present? || order_by == 'fortuneRank'
        parts << company_ios_apps_query(company_filters) if company_filters.present?
      end

      # Excludes taken down apps
      parts << "where.not(display_type: 1)"
      
      # add app filters

      parts << ios_apps_query(app_filters) if app_filters.present?

      parts << "group('ios_apps.id')"
      
      # branch off parts for a first query to count the apps
      parts_count = Array.new(parts)
      parts_count << 'count.length'

      # the query for count; will be run at the end
      query_count = parts_count.join('.')
      
      # add limit and offset

      parts << "limit(#{page_size}).offset(#{(page_num - 1) * page_size})"
      
      parts << ios_sort_order_query(sort_by, order_by)
      
      query = parts.join('.')

      #run the query for count
      results_count = IosApp.instance_eval("self.#{query_count}")

      #run the main query
      results = IosApp.instance_eval("self.#{query}")

      {results_count: results_count, results: results}
    end
    
    def filter_android_apps(app_filters: nil, company_filters: nil, custom_keywords: nil, page_size: 50, page_num: 1, sort_by: 'appName', order_by: 'ASC')
      
      # individual parts of the giant query which will be executed at the end
      # all elements of the array will be chained together
      parts = []

      # parts << "where.not(taken_down: true)"
      # parts << "where(taken_down: nil)"
      
      parts << "includes(:android_developer, :android_fb_ad_appearances, newest_android_app_snapshot: :android_app_categories, websites: :company).joins(:newest_android_app_snapshot).where('android_app_snapshots.name IS NOT null')"
      
      parts << android_app_keywords_query(custom_keywords) if custom_keywords.present?
      
      if company_filters.present? || order_by == 'fortuneRank'
        parts << company_android_apps_query(company_filters) if company_filters.present?
      end

      # Excludes taken down apps
      parts << "where.not(display_type: 1)"

      # add app filters
      parts << android_apps_query(app_filters) if app_filters.present?
      
      parts << "group('android_apps.id')"
      
      # branch off parts for a first query to count the apps
      parts_count = Array.new(parts)
      
      parts_count << 'count.length'
      
      # the query for count; will be run at the end
      query_count = parts_count.join('.')
      
      # add limit and offset
      parts << "limit(#{page_size}).offset(#{(page_num - 1) * page_size})"
      
      parts << android_sort_order_query(sort_by, order_by)
      
      query = parts.join('.')

      #run the query for count
      results_count = AndroidApp.instance_eval("self.#{query_count}")

      #run the main query
      results = AndroidApp.instance_eval("self.#{query}")

      {results_count: results_count, results: results}
    end
    
    def ios_app_keywords_query(keywords)
      name_query_array = keywords.map{|k| "ios_app_snapshots.name LIKE ? OR companies.name LIKE ?"}
      keywords_with_quotes = keywords.map{|k| "\"#{k}%\", \"#{k}%\""}
      # name_query_array = keywords.map{|k| "ios_app_snapshots.name LIKE ?"}
      # keywords_with_quotes = keywords.map{|k| "\"%#{k}%\""}
      "joins(:newest_ios_app_snapshot).where(\'#{name_query_array.join(' OR ')}\', #{keywords_with_quotes.join(',')})"
    end
    
    def android_app_keywords_query(keywords)
      name_query_array = keywords.map{|k| "android_app_snapshots.name LIKE ? OR companies.name LIKE ?"}
      keywords_with_quotes = keywords.map{|k| "\"#{k}%\", \"#{k}%\""}
      # name_query_array = keywords.map{|k| "android_app_snapshots.name LIKE ?"}
      # keywords_with_quotes = keywords.map{|k| "\"%#{k}%\""}
      "joins(:newest_android_app_snapshot).where(\'#{name_query_array.join(' OR ')}\', #{keywords_with_quotes.join(',')})"
    end
    
    def ios_sort_order_query(sort_by, order_by)
      case sort_by
      when 'appName'
        return "where(\'ios_app_snapshots.name is not null\').order(\'ios_app_snapshots.name #{order_by}\')"
      when 'fortuneRank'
        return "where(\'companies.fortune_1000_rank is not null\').order(\'companies.fortune_1000_rank #{order_by}\')"
      when 'lastUpdated'
        return "where(\'ios_app_snapshots.released is not null\').order(\'ios_app_snapshots.released #{order_by}\')"
      when 'companyName'
        return "where(\'companies.name is not null\').order(\'companies.name #{order_by}\')"
      when 'developerName'
        return "where(\'ios_developers.name is not null\').order(\'ios_developers.name #{order_by}\')"
      when 'mobilePriority'
        return "where(\'ios_apps.mobile_priority is not null\').order(\'ios_apps.mobile_priority #{order_by}\')"
      when 'oldAdSpend'
        return "order(\'ios_fb_ad_appearances.ios_app_id #{order_by}\')"
      when 'adSpend'
        return "order(\'ios_fb_ads.ios_app_id #{order_by}\')"
      when 'userBases'
        return "where(\'ios_apps.user_base is not null\').order(\'ios_apps.user_base #{order_by}\')"
      when 'categories'
        return "where(\'ios_app_categories.name is not null\').order(\'ios_app_categories.name #{order_by}\')"
      end
    end
    
    def android_sort_order_query(sort_by, order_by)
      case sort_by
      when 'appName'
        return "where(\'android_app_snapshots.name is not null\').order(\'android_app_snapshots.name #{order_by}\')"
      when 'fortuneRank'
        return "where(\'companies.fortune_1000_rank is not null\').order(\'companies.fortune_1000_rank #{order_by}\')"
      when 'lastUpdated'
        return "where(\'android_app_snapshots.released is not null\').order(\'android_app_snapshots.released #{order_by}\')"
      when 'companyName'
        return "where(\'companies.name is not null\').order(\'companies.name #{order_by}\')"
      when 'developerName'
        return "where(\'android_developers.name is not null\').order(\'android_developers.name #{order_by}\')"
      when 'mobilePriority'
        return "where(\'android_apps.mobile_priority is not null\').order(\'android_apps.mobile_priority #{order_by}\')"
      when 'adSpend'
        return "order(\'android_fb_ad_appearances.android_app_id #{order_by}\')"
      when 'userBases'
        return "where(\'android_apps.user_base is not null\').order(\'android_apps.user_base #{order_by}\')"
      when 'downloads'
        return "where(\'android_app_snapshots.downloads_min is not null\').order(\'android_app_snapshots.downloads_min #{order_by}\')"
      when 'categories'
        return "where(\'android_app_categories.name is not null\').order(\'android_app_categories.name #{order_by}\')"
      end
    end
    
    def ios_apps_with_keywords(keywords)
      name_query_array = keywords.map{|k| "ios_app_snapshots.name LIKE \'%#{k}%\'"}
      name_query_string = name_query_array.join(' OR ')
      IosApp.includes(:ios_fb_ad_appearances, newest_ios_app_snapshot: :ios_app_categories, websites: :company).joins(:newest_ios_app_snapshot).where(name_query_string)
    end
    
    def android_apps_with_keywords(keywords)
      name_query_array = keywords.map{|k| "android_app_snapshots.name LIKE \'%#{k}%\'"}
      name_query_string = name_query_array.join(' OR ')
      IosApp.includes(:android_fb_ad_appearances, newest_android_app_snapshot: :android_app_categories, websites: :company).joins(:newest_android_app_snapshot).where(name_query_string)
    end
    
    def companies_with_keywords(keywords)
      name_query_array = keywords.map{|k| "name LIKE \'%#{k}%\'"}
      name_query_string = name_query_array.join(' OR ')
      Company.where(name_query_string)
    end
    
    def ios_apps_of_companies(companies)
      if companies.present?
        return IosApp.includes(:ios_fb_ad_appearances, newest_ios_app_snapshot: :ios_app_categories, websites: :company).joins(ios_apps_websites: {website: :company}).where("companies.id IN (#{companies.pluck(:id).join(',')})")
      else
        return IosApp.where(id: nil).where('id IS NOT ?', nil)
      end
    end
    
    def android_apps_of_companies(companies)
      if companies.present?
        return AndroidApp.includes(:android_fb_ad_appearances, newest_android_app_snapshot: :android_app_categories, websites: :company).joins(android_apps_websites: {website: :company}).where("companies.id IN (#{companies.pluck(:id).join(',')})")
      else
        return AndroidApp.where(id: nil).where('id IS NOT ?', nil)
      end
    end
    
    def ios_apps_of_snapshots(snapshots)
      app_ids = snapshots.pluck(:ios_app_id)
      IosApp.where(id: app_ids)
    end
    
    def ios_app_union(relation1, relation2)
      app_ids = relation1.pluck(:id) + relation2.pluck(:id)
      IosApp.where(id: app_ids.uniq)
    end
  end
end