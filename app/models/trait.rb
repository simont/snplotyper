class Trait < ActiveRecord::Base
  has_many :strains, :through => :trait_measurements
  
  validates_presence_of :code
  validates_uniqueness_of :code # shouldnt have the same trait code twice
end
