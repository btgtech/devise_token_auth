class CreateAuthentications < ActiveRecord::Migration
  def change
    create_table :authentications do |t|
      ## unique oauth id
      t.references :user
      t.string :provider
      t.string :uid, :null => false, :default => ""
    end
    add_index :authentications, [:uid, :provider],     :unique => true
  end
end
