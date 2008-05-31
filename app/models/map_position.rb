class MapPosition < ActiveRecord::Base
  belongs_to :map
  belongs_to :mappable, :polymorphic => true
  belongs_to :marker, :class_name => "Marker", :foreign_key => "mappable_id"
  
  
  
end
