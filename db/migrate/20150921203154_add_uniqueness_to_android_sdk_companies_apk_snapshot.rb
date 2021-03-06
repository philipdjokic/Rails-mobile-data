class AddUniquenessToAndroidSdkCompaniesApkSnapshot < ActiveRecord::Migration
  def change

  	remove_index :android_sdk_companies_apk_snapshots, name: 'index_apk_snapshot_id_android_sdk_company_id'

    add_index :android_sdk_companies_apk_snapshots, [:apk_snapshot_id, :android_sdk_company_id], name: 'index_apk_snapshot_id_android_sdk_company_id2' if !index_exists?(:android_sdk_companies_apk_snapshots, [:apk_snapshot_id, :android_sdk_company_id])

  end
end
