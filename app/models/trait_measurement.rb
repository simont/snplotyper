class TraitMeasurement < ActiveRecord::Base
  belongs_to :strain
  belongs_to :trait
  
  validates_presence_of :strain_id, :trait_id, :value
end
