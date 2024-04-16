class CreateFeatures < ActiveRecord::Migration[7.0]
  def change
    create_table :features do |t|
      t.string :external_id
      t.decimal :magnitude
      t.string :place
      t.string :time
      t.string :tsunami
      t.string :mag_type
      t.string :title
      t.string :external_url
      t.decimal :latitude
      t.decimal :longitude
      t.timestamps
    end
  end
end