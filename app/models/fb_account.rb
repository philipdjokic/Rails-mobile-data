class FbAccount < ActiveRecord::Base
  has_many :fb_activities
  has_many :ios_fb_ads
  has_many :ios_fb_ad_exceptions

  has_many :fb_accounts_ios_devices
  has_many :ios_devices, through: :fb_accounts_ios_devices
end
