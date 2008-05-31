class Map < ActiveRecord::Base
  #has_many :markers, :through => :map_positions
  has_many :map_positions
  
  has_many :marker_map_positions, :through => :map_positions, :source => :marker, :conditions => "map_positions.mappable_type = 'Marker'"
  
  def find_on_chr_between_start_and_stop(chromosome, start, stop)
    
    positions = []
    
    # in case they enter data backwards, where the start value is greater than the stop value
    if start > stop
      positions = MapPosition.find(:all, :conditions=>["map_id = ? and chromosome_number = ? and start >= ? and end <= ?",self.id,chromosome, stop, start], :order => "start ASC")
    else
      positions = MapPosition.find(:all, :conditions=>["map_id = ? and chromosome_number = ? and start >= ? and end <= ?",self.id,chromosome, start, stop], :order => "start ASC")
    end
    
    markers = Hash.new
    positions.each do |pos|
      # $LOG.warn("Found Marker: #{pos.marker.symbol} of class #{pos.marker.class.to_s}")
      if markers.include?(pos.marker.class.to_s)
        markers[pos.marker.class.to_s] << pos.marker
      else
        markers[pos.marker.class.to_s] = [pos.marker]
      end
      
    end
    return markers
  end
  
  def count_on_chr_between_start_and_stop(chromosome, start, stop)
    
    count = 0
    
    # in case they enter data backwards, where the start value is greater than the stop value
    if start > stop
       count = MapPosition.count(:all, :conditions=>["map_id = ? and chromosome_number = ? and start >= ? and end <= ?",self.id,chromosome, stop, start], :order => "start ASC")
    else
       count = MapPosition.count(:all, :conditions=>["map_id = ? and chromosome_number = ? and start >= ? and end <= ?",self.id,chromosome, start, stop], :order => "start ASC")
    end
    
   
    
    return count
  end
  
end
