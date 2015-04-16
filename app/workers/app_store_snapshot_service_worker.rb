class AppStoreSnapshotServiceWorker
  include Sidekiq::Worker
  
  # accounting for retries ourself, so disable sidekiq retries
  sidekiq_options retry: false
  
  MAX_TRIES = 3
  
  # def perform(ios_app_snapshot_job_id, ios_app_ids)
  #
  #   ios_app_ids.each do |ios_app_id|
  #     next unless IosAppSnapshot.where(ios_app_snapshot_job_id: ios_app_snapshot_job_id, ios_app_id: ios_app_id).blank?
  #
  #     save_attributes(ios_app_id: ios_app_id, ios_app_snapshot_job_id: ios_app_snapshot_job_id)
  #   end
  #
  # end
  
  def perform(ios_app_snapshot_job_id, ios_app_id)
    
    save_attributes(ios_app_id: ios_app_id, ios_app_snapshot_job_id: ios_app_snapshot_job_id)

  end
  
  # def perform
  #   logger.info "in perform"
  #   SidekiqTester.create!(test_string: 'in perform', ip: MyIp.ip)
  # end
  
  def save_attributes(options={})
    ios_app = IosApp.find(options[:ios_app_id])
    
    ios_app_snapshot_job_id = options[:ios_app_snapshot_job_id]
    s = IosAppSnapshot.create(ios_app: ios_app, ios_app_snapshot_job_id: ios_app_snapshot_job_id)
    
    try = 0
    
    begin
      
      a = AppStoreService.attributes(ios_app.app_identifier)
      
      raise 'AppStoreService.attributes is empty' if a.empty?
    
      single_column_attributes = %w(
        name
        description
        release_notes
        version
        price
        size
        seller
        recommended_age
        required_ios_version
        released
        editors_choice
        developer_app_store_identifier
        icon_url_350x350
        icon_url_175x175
      )
    
      single_column_attributes.each do |sca|
        value = a[sca.to_sym]
        s.send("#{sca}=", value) if value
      end
    
      # Categories
      if categories = a[:categories]
        categories_snapshot_primary = IosAppCategoriesSnapshot.new
        categories_snapshot_primary.ios_app_snapshot = s
        categories_snapshot_primary.ios_app_category = IosAppCategory.find_or_create_by(name: categories[:primary])
        categories_snapshot_primary.kind = :primary
        categories_snapshot_primary.save!
    
        categories_snapshot_secondary = IosAppCategoriesSnapshot.new
        categories[:secondary].each do |secondary_category|
          categories_snapshot_secondary.ios_app_snapshot = s
          categories_snapshot_secondary.ios_app_category = IosAppCategory.find_or_create_by(name: secondary_category)
          categories_snapshot_secondary.kind = :secondary
        end
        categories_snapshot_secondary.save!
      end
    
      if ratings = a[:ratings]
        if ratings_current = ratings[:current]
          ratings_current_count = ratings_current[:count].to_i
          s.ratings_current_count = ratings_current_count
          s.ratings_current_stars = ratings_current[:stars]
          
          if released = a[:released]
            days_ago = (Date.tomorrow - released).to_i
            ratings_per_day_current_release = ratings_current_count/(days_ago.to_f)
            s.ratings_per_day_current_release = ratings_per_day_current_release
          end
          
        end
        
      
        if ratings_all = ratings[:all]
          ratings_all_count = ratings_all[:count].to_i #store in memory bc we need it later
          s.ratings_all_count = ratings_all_count
          
          s.ratings_all_stars = ratings_all[:stars]
        end
      end
    
      if seller_url = a[:seller_url]
        s.seller_url = seller_url
        #TODO: add logic around company
      end
    
    
      if support_url = a[:support_url]
         s.support_url = support_url
         #TODO: add logic around company
      end
   
    
      if languages = a[:languages]
        languages.each do |language_name|
          s.ios_app_languages << IosAppLanguage.find_or_create_by(name: language_name)
        end
      end
    
      if in_app_purchases = a[:in_app_purchases]
        in_app_purchases.each do |in_app_purchase|
          IosInAppPurchase.create(name: in_app_purchase[:name], price: in_app_purchase[:price], ios_app_snapshot: s)
        end
      end
      
      if icon_urls = a[:icon_urls]
        
        if size_350x350 = icon_urls[:size_350x350]
          s.icon_url_350x350 = size_350x350
        end
        if size_175x175 = icon_urls[:size_175x175]
          s.icon_url_175x175 = size_175x175
        end
      end
    
      puts "#0"
    
      s.save!
      
      puts "#1"
      
      #set user base
      if defined?(ratings_all_count) && defined?(ratings_per_day_current_release)
        puts "#2"
        if ratings_per_day_current_release >= 7 || ratings_all_count >= 50e3
          user_base = :elite
        elsif ratings_per_day_current_release >= 1 || ratings_all_count >= 10e3
          user_base = :strong
        elsif ratings_per_day_current_release >= 0.1 || ratings_all_count >= 100
          user_base = :moderate
        else
          user_base = :weak
        end
        
        puts "#3"
        
        ios_app.user_base = user_base
      end
      
      puts "#4"
      
      #set mobile priority
      if released = a[:released]
        if ios_app.ios_fb_ad_appearances.present? || released > 2.months.ago
          mobile_priority = :high
        elsif released > 4.months.ago
          mobile_priority = :medium
        else
          mobile_priority = :low
        end
        
        puts "#5"
        
        ios_app.mobile_priority = mobile_priority
      end
      
      puts "#6"
      
      #update newest snapshot
      ios_app.newest_ios_app_snapshot = s
      
      puts "#7"
      
      ios_app_save_success = ios_app.save
      
      puts "#8, #{ios_app_save_success}"
    
    rescue => e
      ise = IosAppSnapshotException.create(ios_app_snapshot: s, name: e.message, backtrace: e.backtrace, try: try, ios_app_snapshot_job_id: ios_app_snapshot_job_id)
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
    
    ios_app_ids = ids.map{ |id| IosApp.find_or_create_by(app_identifier: id) }
    
    perform(-1, ios_app_ids)
  end
  
end