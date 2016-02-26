class IosApp < ActiveRecord::Base

  validates :app_identifier, uniqueness: true
  # validates :app_stores, presence: true #can't have an IosApp if it's not connected to an App Store

  has_many :ipa_snapshot_job_exceptions
  has_many :ios_app_snapshots
  belongs_to :app
  has_many :ios_fb_ad_appearances
  has_many :ios_app_download_snapshots
  has_many :ipa_snapshots
  
  has_many :ios_apps_websites  
  has_many :websites, through: :ios_apps_websites

  has_many :listables_lists, as: :listable
  has_many :lists, through: :listables_lists
  
  belongs_to :newest_ios_app_snapshot, class_name: 'IosAppSnapshot', foreign_key: 'newest_ios_app_snapshot_id'
  belongs_to :newest_ipa_snapshot, class_name: 'IpaSnapshot', foreign_key: 'newest_ipa_snapshot_id'
  
  has_many :app_stores_ios_apps
  has_many :app_stores, -> { uniq }, through: :app_stores_ios_apps
  
  belongs_to :ios_developer
  
  enum mobile_priority: [:high, :medium, :low]
  enum user_base: [:elite, :strong, :moderate, :weak]
  enum display_type: [:normal, :taken_down, :foreign, :device_incompatible, :paid, :not_ios]
  
  WHITELISTED_APPS = [404249815,297606951,447188370,368677368,324684580,477128284,
                      529479190, 547702041,591981144,618783545,317469184,401626263]

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
  
  def get_website_urls
    self.websites.to_a.map{|w| w.url}
  end

  def website
    self.get_website_urls.first
  end

  def icon_url(size) # size should be string eg '350x350'
    if newest_ios_app_snapshot.present?
      return newest_ios_app_snapshot.send("icon_url_#{size}")
    end
  end

  def sdk_response
    IosSdkService.get_sdk_response(self.id)
  end
  
  def name
    if newest_ios_app_snapshot.present?
      return newest_ios_app_snapshot.name
    else
      return nil
    end
  end

  def price
    if newest_ios_app_snapshot.present?
      (newest_ios_app_snapshot.price.to_i > 0) ? "$#{newest_ios_app_snapshot.price}" : 'Free' 
    end
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
