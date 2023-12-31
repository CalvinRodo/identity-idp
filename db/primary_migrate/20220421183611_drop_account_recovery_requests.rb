class DropAccountRecoveryRequests < ActiveRecord::Migration[6.1]
  def up
    drop_table :account_recovery_requests
  end

  def down
    create_table :account_recovery_requests do |t|
      t.integer :user_id, null: false
      t.string :request_token, null: false
      t.datetime :requested_at, null: false
      t.timestamps
    end
    add_index :account_recovery_requests, %i[user_id], unique: true, using: :btree
    add_index :account_recovery_requests, %i[request_token], unique: true, using: :btree
  end
end
