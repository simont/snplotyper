class Genotype < ActiveRecord::Base
  belongs_to :strain
  belongs_to :genotypable, :polymorphic => true
  belongs_to :marker, :class_name => "Marker", :foreign_key => "genotypable_id"
  
  
  # Subroutine to return the genotype information that a user would expect to see for a marker
  # this defaults to genotype_allele but for some types or markers, this isnt what you need
  # (eg SSLP should return the allele size rather than a nucleotide genotype)
  
  def get_public_genotype
    if self.marker.class.to_s == "Snp"
      return self.genotype_allele
    else
      return self.size
    end
  end
  
  def get_numeric_genotype
    if self.marker.class.to_s == "Snp"
      return self.genotype_code <= 2 ? self.genotype_code : -1
    else
      return self.size != nil ? self.size : -1
    end
  end
  
end
