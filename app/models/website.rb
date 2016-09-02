class Website < ActiveRecord::Base
  belongs_to :company
  
  has_many :ios_apps_websites
  has_many :ios_apps, through: :ios_apps_websites

  has_many :android_apps_websites
  has_many :android_apps, through: :android_apps_websites

  has_many :ios_developers_websites
  has_many :ios_developers, through: :ios_developers_websites

  has_many :android_developers_websites
  has_many :android_developers, through: :android_developers_websites

  has_many :clearbit_contacts

  enum kind: [:primary, :secondary]
  
  validates :url, presence: true

end
