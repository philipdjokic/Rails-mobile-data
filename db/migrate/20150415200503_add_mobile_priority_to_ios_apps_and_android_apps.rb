class AddMobilePriorityToIosAppsAndAndroidApps < ActiveRecord::Migration
  def change
    add_column :android_apps, :mobile_priority, :integer
    add_index :android_apps, :mobile_priority
    
    add_column :ios_apps, :mobile_priority, :integer
    add_index :ios_apps, :mobile_priority
  end
end
