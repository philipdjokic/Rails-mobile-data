class CreateApkSnapshotExceptions < ActiveRecord::Migration
  def change
    create_table :apk_snapshot_exceptions do |t|
      t.integer :apk_snapshot_id
      t.text :name
      t.text :backtrace
      t.integer :try
      t.integer :apk_snapshot_job_id
      t.integer :google_account_id

      t.timestamps
    end
    add_index :apk_snapshot_exceptions, :apk_snapshot_id
    add_index :apk_snapshot_exceptions, :apk_snapshot_job_id
    add_index :apk_snapshot_exceptions, :google_account_id
  end
end
