class CreateUrls < ActiveRecord::Migration[7.0]
  def change
    create_table :urls do |t|
      t.string :original_url
      t.string :short_url
      t.string :token
      t.integer :visit_count
      t.string :alias
      t.timestamps
    end
    add_index :urls, :short_url, unique: true
  end
end
