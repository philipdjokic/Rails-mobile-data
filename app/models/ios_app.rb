class IosApp < ActiveRecord::Base
  include AppAds
  include MobileApp

  validates :app_identifier, uniqueness: true
  # validates :app_stores, presence: true #can't have an IosApp if it's not connected to an App Store

  has_many :ipa_snapshot_job_exceptions
  has_many :ios_app_snapshots
  belongs_to :app
  has_many :ios_fb_ad_appearances
  has_many :ios_app_download_snapshots
  has_many :ipa_snapshots
  has_many :ipa_snapshot_lookup_failures

  has_many :class_dumps, through: :ipa_snapshots

  has_many :ios_apps_websites
  has_many :websites, through: :ios_apps_websites

  has_many :listables_lists, as: :listable
  has_many :lists, through: :listables_lists

  belongs_to :newest_ios_app_snapshot, class_name: 'IosAppSnapshot', foreign_key: 'newest_ios_app_snapshot_id'
  has_many :ios_app_current_snapshots
  has_many :ios_app_current_snapshot_backups
  belongs_to :newest_ipa_snapshot, class_name: 'IpaSnapshot', foreign_key: 'newest_ipa_snapshot_id'

  has_many :app_stores_ios_apps
  has_many :app_stores, -> { uniq }, through: :app_stores_ios_apps
  has_many :app_store_ios_apps_backups
  has_many :app_store_backups, source: :app_store, through: :app_store_ios_apps_backups

  belongs_to :ios_developer

  has_many :weekly_batches, as: :owner
  has_many :follow_relationships
  has_many :followers, as: :followable, through: :follow_relationships
  has_many :ios_fb_ads

  has_many :ios_app_rankings

  has_many :owner_twitter_handles, as: :owner
  has_many :twitter_handles, through: :owner_twitter_handles

  enum mobile_priority: [:high, :medium, :low]
  enum user_base: [:elite, :strong, :moderate, :weak] # this order matters...don't change or add more
  enum display_type: [:normal, :taken_down, :foreign, :device_incompatible, :paid, :not_ios]
  enum source: [:epf_weekly, :ewok, :itunes_top_200]

  scope :is_ios, ->{where.not(display_type: display_types[:not_ios])}

  ad_table :ios_fb_ads
  # update_index('apps#ios_app') { self } if Rails.env.production?

  WHITELISTED_APPS = [404249815,297606951,447188370,368677368,324684580,477128284,
                      529479190, 547702041,591981144,618783545,317469184,401626263,1094591345]

  def invalidate_newest_ipa_snapshot
    ipa_snapshot = get_last_ipa_snapshot(scan_success: true)

    ipa_snapshot.update(scan_status: :invalidated)

    update_newest_ipa_snapshot
  end

  def update_newest_ipa_snapshot
    ipa_snapshot = get_last_ipa_snapshot(scan_success: true)

    self.update(newest_ipa_snapshot: ipa_snapshot)
  end

  def get_newest_download_snapshot
    self.ios_app_download_snapshots.max_by do |snapshot|
      snapshot.updated_at
    end
  end

  def get_last_ipa_snapshot(scan_success: false)
    if scan_success
      self.ipa_snapshots.where(scan_status: IpaSnapshot.scan_statuses[:scanned]).order([:good_as_of_date, :id]).last
    else
      self.ipa_snapshots.order(:good_as_of_date).last
    end
  end

  def get_company
    self.websites.each do |w|
      if w.company.present?
        return w.company
      end
    end
    return nil
  end

  # allow stubbing of getter for test
  def fb_app_data(getter: nil)
    return nil unless fb_app_id.present?
    getter ||= FbAppData.new(fb_app_id)
    getter.latest
  end

  def monthly_active_users
    fb_app_data.try(:[], 'monthly_active_users').try(:to_i)
  end

  def monthly_active_users_rank
    fb_app_data.try(:[], 'monthly_active_users_rank')
  end

  def daily_active_users
    fb_app_data.try(:[], 'daily_active_users').try(:to_i)
  end

  def daily_active_users_rank
    fb_app_data.try(:[], 'daily_active_users_rank')
  end

  def weekly_active_users
    fb_app_data.try(:[], 'weekly_active_users').try(:to_i)
  end

  def platform
    'ios'
  end

  def as_json(options={})
    newest_snapshot = self.newest_ios_app_snapshot

    batch_json = {
      id: self.id,
      type: self.class.name,
      platform: platform,
      releaseDate: self.release_date,
      name: self.name,
      mobilePriority: first_international_snapshot.try(:mobile_priority) || mobile_priority,
      userBase: self.international_userbase(user_bases: options[:user_bases]),
      userBases: self.scored_user_bases,
      releasedDays: self.released_days,
      lastUpdated: self.last_updated,
      lastUpdatedDays: self.last_updated_days,
      seller: self.seller,
      supportDesk: self.support_url,
      categories: self.categories,
      icon: self.icon_url,
      adSpend: self.ad_spend? || self.old_ad_spend?,
      price: first_international_snapshot.try(:price) || newest_snapshot.try(:price),
      currency: self.currency,
      rankingChange: self.ranking_change,
      appAvailable: self.app_store_available,
      appStoreLink: self.app_store_link,
      appStores: {totalCount: AppStore.enabled.count, availableIn: self.app_stores.map{|store| {name: store.name, country_code: store.country_code}}},
      isInternational: self.international?,
      fortuneRank: self.fortune_rank,
      publisher: {
        id: self.try(:ios_developer).try(:id),
        name: self.try(:ios_developer).try(:name) || first_international_snapshot.try(:seller_name),
        websites: self.try(:ios_developer).try(:get_website_urls)
      },
    }

    if options[:ads]
      batch_json.merge!({
        first_seen_ads_date: self.first_seen_ads_date,
        first_seen_ads_days: self.first_seen_ads_days,
        last_seen_ads_date: self.last_seen_ads_date,
        last_seen_ads_days: self.last_seen_ads_days,
        latest_facebook_ad: self.latest_facebook_ad.as_json({no_app: true}),
        ad_attribution_sdks: self.ad_attribution_sdks
      })
    end

    if options[:engagement]
      batch_json.merge!({
        wau: ActionController::Base.helpers.number_to_human(self.weekly_active_users),
        dau: ActionController::Base.helpers.number_to_human(self.daily_active_users),
        dau_rank: ActionController::Base.helpers.number_to_human(self.daily_active_users_rank),
        mau: ActionController::Base.helpers.number_to_human(self.monthly_active_users),
        mau_rank: ActionController::Base.helpers.number_to_human(self.monthly_active_users_rank),
      })
    end

    if options[:details]
      batch_json.merge!({
        currentVersion: self.version,
        currentVersionDescription: self.release_notes,
        rating: self.rating,
        ratingsCount: self.ratings_count,
        ratings: self.ratings,
        ratingsCounts: self.ratings_counts,
        inAppPurchases: newest_snapshot.try(:ios_in_app_purchases).try(:any?),
        appIdentifier: self.app_identifier,
        appStoreId: self.developer_app_store_id,
        size: self.size,
        requiredIosVersion: self.required_ios_version,
        recommendedAge: self.recommended_age,
        description: self.description,
        facebookAds: self.ios_fb_ads.has_image.as_json({no_app: true}),
        headquarters: self.headquarters,
      })
    end

    batch_json[:rank] = self.rank if self.respond_to?(:rank)

    if options[:user]
      batch_json[:following] = options[:user].following?(self)
      batch_json[:adSpend] = options[:user].account.can_view_ad_spend? ? self.ad_spend? : self.old_ad_spend?
    end

    if options[:account]
      batch_json[:following] = options[:account].following?(self)
    end

    batch_json
  end

  def size
    first_international_snapshot.try(:size) || newest_ios_app_snapshot.try(:size)
  end

  def required_ios_version
    first_international_snapshot.try(:required_ios_version) || newest_ios_app_snapshot.try(:required_ios_version)
  end

  def recommended_age
    first_international_snapshot.try(:recommended_age) || newest_ios_app_snapshot.try(:recommended_age)
  end

  def description
    first_international_snapshot.try(:description) || newest_ios_app_snapshot.try(:description)
  end

  def last_scanned
    get_last_ipa_snapshot(scan_success: true).try(:good_as_of_date)
  end

  def developer_app_store_id
    first_international_snapshot.try(:developer_app_store_identifier) || newest_ios_app_snapshot.try(:developer_app_store_identifier)
  end

  def categories
    ios_app_current_snapshots.joins(:ios_app_categories).pluck("ios_app_categories.name").uniq
  end

  def user_bases
    if ios_app_current_snapshots.any?
      ios_app_current_snapshots
        .joins(:app_store)
        .select('app_stores.country_code, app_stores.name, user_base')
        .map{|app| {country_code: app.country_code, user_base: app.user_base, country: app.name} }
    else
      [{country_code: 'US', user_base: user_base, country: 'United States'}]
    end
  end

  def scored_user_bases
    country_count = AppStore.enabled.count
    self.user_bases.map do |userbase|
      display_priority = AppStore.find_by(country_code: userbase[:country_code]).display_priority
      base = userbase[:user_base] || 'weak'
      base_score = IosApp.user_bases[base]
      score = base_score * country_count + display_priority
      userbase.merge({ score: score })
    end.sort { |a, b| a[:score] <=> b[:score] }
  end

  def user_base_display_score
    self.scored_user_bases.first[:score]
  end

  def rating
    if first_international_snapshot
      {rating: first_international_snapshot.try(:ratings_all_stars), country_code: first_international_snapshot.try(:app_store).try(:country_code)}
    else
      {country_code: 'US', rating: newest_ios_app_snapshot.try(:ratings_all_stars)}
    end
  end

  def ratings
    if ios_app_current_snapshots.any?
      ios_app_current_snapshots.joins(:app_store).select('app_stores.country_code, app_stores.name, ratings_all_stars').map{|app| {country_code: app.country_code, rating: app.ratings_all_stars, country: app.name}}
    else
      [{country_code: 'US', rating: newest_ios_app_snapshot.try(:ratings_all_stars), country: 'United States'}]
    end
  end

  def ratings_count
    if first_international_snapshot
      {ratings_count: first_international_snapshot.try(:ratings_all_count), country_code: first_international_snapshot.try(:app_store).try(:country_code)}
    else
      {country_code: 'US', ratings_count: newest_ios_app_snapshot.try(:ratings_all_count)}
    end
  end

  def ratings_counts
    if ios_app_current_snapshots.any?
      ios_app_current_snapshots.joins(:app_store).select('app_stores.country_code, app_stores.name, ratings_all_count').map{|app| {country_code: app.country_code, ratings_count: app.ratings_all_count, country: app.name}}
    else
      [{country_code: 'US', ratings_count: newest_ios_app_snapshot.try(:ratings_all_count), country: 'United States'}]
    end
  end

  def latest_facebook_ad
    latest_ad
  end

  def international?
    !app_stores.pluck(:country_code).include?('US')
  end

  def international_userbase(user_bases: nil)
    if user_bases.present?
      intl_snapshot = first_international_snapshot(user_bases: user_bases)
      return intl_snapshot ? {user_base: intl_snapshot.try(:user_base), country_code: intl_snapshot.try(:app_store).try(:country_code)} : {user_base: self.user_base, country_code: 'US'}
    end
    scored_user_bases.first
  end

  def first_international_snapshot(country_code: nil, user_bases: nil)
    order_string = "display_priority IS NULL, display_priority ASC"

    snapshot = ios_app_current_snapshots.joins(:app_store)
    if user_bases.present?
      mapped_user_bases = user_bases.map{|user_base| IosApp.user_bases[user_base]}
      order_string = "user_base ASC, #{order_string}"
      userbase_snapshot = snapshot.where(user_base: mapped_user_bases)
      snapshot = userbase_snapshot if userbase_snapshot.any?
    end
    snapshot = snapshot.where('app_stores.country_code = ?', country_code) if country_code
    snapshot.order(order_string).first
  end

  def old_ad_spend?
    self.ios_fb_ad_appearances.any?
  end

  def ad_spend?
    self.ios_fb_ads.any?
  end

  def seller_url
    first_international_snapshot.try(:seller_url) || self.newest_ios_app_snapshot.try(:seller_url)
  end

  def support_url
    self.newest_ios_app_snapshot.try(:support_url)
  end

  def get_website_urls
    self.websites.pluck(:url).uniq
  end

  def seller
    first_international_snapshot.try(:seller) || newest_ios_app_snapshot.try(:seller)
  end

  def app_store_link
    "https://itunes.apple.com/us/app/id#{self.app_identifier}"
  end

  def last_updated
    first_international_snapshot.try(:released).try(:to_s) || newest_ios_app_snapshot.try(:released).try(:to_s)
  end

  def top_200_rank
    self.ios_app_rankings.last.rank
  end

  def is_in_top_200?
    newest_rank_snapshot = IosAppRankingSnapshot.last_valid_snapshot
    return false unless newest_rank_snapshot
    newest_rank_snapshot.ios_app_rankings.where(ios_app_id: self.id).any?
  end

  def ranking_change
    newest_rank_snapshot = IosAppRankingSnapshot.last_valid_snapshot
    newest_rank = newest_rank_snapshot.ios_app_rankings.where(ios_app_id: self.id).first if newest_rank_snapshot
    if newest_rank
      week_ago = newest_rank_snapshot.created_at - 7.days
      last_weeks_rank_snapshot = IosAppRankingSnapshot.where(is_valid: true).where('created_at <=  ?', week_ago.end_of_day).first
      return 0 unless last_weeks_rank_snapshot
      last_weeks_rank = last_weeks_rank_snapshot.ios_app_rankings.where(ios_app_id: self.id).first

      if last_weeks_rank.blank?
        200 - newest_rank.rank + 1
      else
        last_weeks_rank.rank - newest_rank.rank
      end
    end
  end

  def last_updated_days
    released = first_international_snapshot.try(:released) || newest_ios_app_snapshot.try(:released)
    if released
      (Time.now.to_date - released.to_date).to_i
    end
  end

  def app_store_link
    "https://itunes.apple.com/#{first_international_snapshot.try(:app_store).try(:country_code).try(:downcase) || 'us'}/app/id#{self.app_identifier}"
  end

  def ratings_all_count
    first_international_snapshot.try(:ratings_all_count) || newest_ios_app_snapshot.try(:ratings_all_count)
  end

  def released_days
    released =  first_international_snapshot.try(:first_released) || newest_ios_app_snapshot.try(:first_released)
    released ? (Date.today - released).to_i : 0
  end

  def website
    self.get_website_urls.first
  end

  def icon_url(size='350x350') # size should be string eg '350x350'
    url = first_international_snapshot.try(:icon_url_100x100) || newest_ios_app_snapshot.try(:send, "icon_url_#{size}")
    url = url.gsub(/http:\/\/is([0-9]+).mzstatic/, 'https://is\1-ssl.mzstatic') if url.present?
  end

  def sdk_response
    IosSdkService.get_sdk_response(self.id)
  end

  def tagged_sdk_response(only_show_tagged=false)
    IosSdkService.get_tagged_sdk_response(self.id, only_show_tagged)
  end

  def installed_sdks
    self.sdk_response[:installed_sdks]
  end

  def uninstalled_sdks
    self.sdk_response[:uninstalled_sdks]
  end

  def fortune_rank
    self.ios_developer.try(:fortune_1000_rank)
  end

  def headquarters(limit=100)
    ios_developer.try(:headquarters, limit) || []
  end

  def release_date
    first_international_snapshot.try(:first_released) || newest_ios_app_snapshot.try(:first_released)
  end

  def name
    first_international_snapshot.try(:name) || newest_ios_app_snapshot.try(:name)
  end

  def price
    snapshot = first_international_snapshot || newest_ios_app_snapshot
    if snapshot
      (snapshot.price.to_i > 0) ? "$#{snapshot.price} #{snapshot.try(:currency)}" : 'Free'
    end
  end

  def currency
    first_international_snapshot.try(:currency) || 'USD'
  end

  def version
    first_international_snapshot.try(:version) || newest_ios_app_snapshot.try(:version)
  end

  def release_notes
    first_international_snapshot.try(:release_notes) || newest_ios_app_snapshot.try(:release_notes)
  end

  def to_csv_row(can_view_support_desk=false)
    # li "CREATING HASH FOR #{app.id}"
    developer = self.ios_developer
    newest_snapshot = self.newest_ios_app_snapshot
    hqs = self.headquarters(1)

    row = [
      self.id,
      self.app_identifier,
      newest_snapshot.try(:name),
      'IosApp',
      self.mobile_priority,
      self.release_date,
      self.last_updated,
      self.ios_fb_ads.any?,
      newest_snapshot.try(:ios_in_app_purchases).try(:any?),
      self.categories.try(:join, ", "),
      developer.try(:id),
      developer.try(:name),
      developer.try(:identifier),
      self.fortune_rank,
      developer.try(:get_website_urls).try(:join, ', '),
      self.link,
      developer.try(:link),
      self.ratings_all_count,
      nil, #downloads for android
      hqs.map{|hq| hq[:street_number]}.join('|'),
      hqs.map{|hq| hq[:street_name]}.join('|'),
      hqs.map{|hq| hq[:city]}.join('|'),
      hqs.map{|hq| hq[:state]}.join('|'),
      hqs.map{|hq| hq[:country]}.join('|'),
      hqs.map{|hq| hq[:postal_code]}.join('|'),
    ]
    AppStore.enabled.order("display_priority IS NULL, display_priority ASC").
                     joins(:ios_app_current_snapshots).where('ios_app_current_snapshots.ios_app_id' => self.id).pluck('user_base').each do |user_base|
      row << IosAppCurrentSnapshot.user_bases.key(user_base)
    end
    row
  end

  ###############################
  # Mobile priority methods
  ###############################

  def set_mobile_priority
    begin
      if ios_fb_ad_appearances.present? || newest_ios_app_snapshot.released > 2.months.ago
        self.mobile_priority = :high
      elsif newest_ios_app_snapshot.released > 4.months.ago
        self.mobile_priority = :medium
      else
        self.mobile_priority = :low
      end
      self.save
    rescue => e
      logger.info "Warning: couldn't update mobile priority for IosApp with id #{self.id}"
      logger.info e
    end
  end

  ########################
  # User Base methods
  ########################

  def set_user_base
    logger.info "updating user base"
    begin
      if self.newest_ios_app_snapshot.ratings_per_day_current_release >= 7 || self.newest_ios_app_snapshot.ratings_all_count >= 50e3
        self.user_base = :elite
      elsif self.newest_ios_app_snapshot.ratings_per_day_current_release >= 1 || self.newest_ios_app_snapshot.ratings_all_count >= 10e3
        self.user_base = :strong
      elsif self.newest_ios_app_snapshot.ratings_per_day_current_release >= 0.1 || self.newest_ios_app_snapshot.ratings_all_count >= 100
        self.user_base = :moderate
      else
        self.user_base = :weak
      end
      self.save
    rescue => e
      logger.info "Warning: couldn't update user_base for IosApp with id #{self.id}"
      logger.info e
    end
  end

  def link(stage: :production, utm_source: nil)
    app_link = if stage == :production
      "https://mightysignal.com/app/app#/app/ios/#{id}"
    elsif stage == :staging
      "https://staging.mightysignal.com/app/app#/app/ios/#{id}"
    end
    app_link += "?utm_source=#{utm_source}" if utm_source
    app_link
  end

  def reset_app_data
    update!(display_type: :normal)
    AppStoreInternationalService.live_scrape_ios_apps([id])
    AppStoreSnapshotServiceWorker.new.perform(nil, id)
    puts 'sleeping to allow intl scrapes'
    sleep 3
    update!(app_store_available: true) if app_stores.any?
    AppStoreDevelopersWorker.new.create_by_ios_app_id(id)
  end

  class << self

    def dedupe
      # find all models and group them on keys which should be common
      grouped = all.group_by{|model| [model.app_identifier] }
      grouped.values.each do |duplicates|
        # the first one we want to keep right?
        first_one = duplicates.shift # or pop for last one
        # if there are any more left, they are duplicates
        # so delete all of them
        duplicates.each do |double|
          puts "double: #{double.app_identifier}"
          double.destroy # duplicates can now be destroyed
        end
      end
    end

  end

end
