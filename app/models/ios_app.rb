class IosApp < ActiveRecord::Base

  has_many :ios_app_snapshots
  belongs_to :app
  has_many :fb_ad_appearances
  has_many :ios_app_download_snapshots
    
  
  def newest_snapshot
    self.ios_app_snapshots.max_by do |snapshot|
      snapshot.updated_at
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
  
end
