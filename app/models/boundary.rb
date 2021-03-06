class Boundary < ActiveRecord::Base
  belongs_to :area, :polymorphic => true
  validates_presence_of :area_id, :area_type, :boundary_line
  
  # NB coords are assumed to be lat_longs. GeoRuby stores them as coords (x,y) -- where x = long, y = lat. We make up polygon (actually a square) going clockwise
  def bounding_box_from_sw_ne=(sw_ne_coords)
    sw, ne = sw_ne_coords
    self[:bounding_box] = Polygon.from_coordinates([[[sw.last, sw.first], [ne.last, sw.first], [ne.last, ne.first], [sw.last, ne.first], [sw.last, sw.first]]])
  end
  
  def bounding_box
    boundary_line.bounding_box
  end
  
  def centrepoint
    boundary_line.envelope.center
  end
  
  def boundary_line_coordinates
    boundary_line.rings.collect do |ring|
      ring.collect{ |point| [point.lat, point.lng] }
    end
  end
end
