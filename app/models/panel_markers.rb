class PanelMarkers < ActiveRecord::Base
  belongs_to :panel
  belongs_to :marker, :class_name => "Marker", :foreign_key => "genotypable_id"
  
  validates_presence_of :panel_id
  validates_presence_of :marker_id

end
