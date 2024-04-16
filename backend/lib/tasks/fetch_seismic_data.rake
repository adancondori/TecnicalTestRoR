namespace :seismic_data do
    desc "Fetches seismic data from USGS"
    task fetch: :environment do
        require 'net/http'
        require 'json'
  
        url = 'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_month.geojson'
        response = Net::HTTP.get(URI(url))
        data = JSON.parse(response)
  
        data["features"].each do |feature|
            next unless feature["properties"]["title"] && feature["properties"]["url"] &&
                        feature["properties"]["place"] && feature["properties"]["magType"] &&
                        feature["properties"]["mag"] && feature["geometry"]["coordinates"][1] &&
                        feature["geometry"]["coordinates"][0]
  
            magnitude = feature["properties"]["mag"]
            latitude = feature["geometry"]["coordinates"][1]
            longitude = feature["geometry"]["coordinates"][0]
    
            next unless magnitude.between?(-1.0, 10.0) &&
                        latitude.between?(-90.0, 90.0) &&
                        longitude.between?(-180.0, 180.0)
    
            next if Feature.exists?(external_id: feature["id"])
            puts "Saved -  #{feature["properties"]["title"]}"
            Feature.create(
                external_id: feature["id"],
                magnitude: magnitude,
                place: feature["properties"]["place"],
                time: Time.at(feature["properties"]["time"] / 1000), 
                tsunami: feature["properties"]["tsunami"],
                mag_type: feature["properties"]["magType"],
                title: feature["properties"]["title"],
                external_url: feature["properties"]["url"],
                latitude: latitude,
                longitude: longitude
            )
        end
    end
end
  