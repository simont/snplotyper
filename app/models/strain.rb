class Strain < ActiveRecord::Base
  # has_many :markers, :through => :genotypes
  belongs_to :population
  has_many :selected_strains
  has_many :analyses, :through => :selected_strains
  has_many :genotypes
  has_many :marker_genotypes, :through => :genotypes, :source => :marker, :conditions => "genotypes.genotypable_type = 'Marker'"
  has_many :trait_measurements
  has_many :traits, :through => :trait_measurements
  
end
