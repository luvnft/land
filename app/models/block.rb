class Block < ApplicationRecord
  def to_geojson
    box = RGeo::Cartesian::BoundingBox.create_from_points(southwest, northeast)
    RGeo::GeoJSON.encode(box.to_geometry).to_json
  end

  def w3w_url
    "https://what3words.com/#{w3w}"
  end

  def populate_coords
    x = W3wApiService.convert_to_coordinates(w3w).fetch('square')
    sw = x.fetch('southwest')
    ne = x.fetch('northeast')

    self.southwest = "POINT(#{sw.fetch('lng')} #{sw.fetch('lat')})"
    self.northeast = "POINT(#{ne.fetch('lng')} #{ne.fetch('lat')})"
  end
end