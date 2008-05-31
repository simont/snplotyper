class Marker < ActiveRecord::Base
  has_many :map_positions, :as => :mappable
  has_many :maps, :through => :map_positions
  
  has_many :genotypes, :as => :genotypable
  has_many :strains, :through => :genotypes
  
  has_many :panel_markers
  has_many :panels, :through => :panel_markers

  
  # has_many :strains, :through  => :genotypes
  
  set_inheritance_column :marker_type # overrides the default 'type' column for the single table inheritance
  
  validates_presence_of :symbol
  validates_uniqueness_of :symbol
  # validates_associated :panel
  
  
  # This method provides a generic way for two markers to decide if they are polymorphic or
  # or not - ie they have different genotypes in the two strains compared. This should be subclassed
  # in the appropriate marker object in order for it to make sense
  
  def is_polymorphic?(strain_id, other_marker)  
    
      genotype1 = self.genotypes.find_by_strain_id(strain_id)
      genotype2 = other_marker.genotypes.find_by_strain_id(strain_id)
      
      if genotype1 == genotype2
        return false
      else
        return true
      end
    
  end
  
end
