class Analysis < ActiveRecord::Base
  has_many :selected_strains
  has_many :strains, :through => :selected_strains, :order => :position
  
  def is_complete?
    
    if self.chromosome != nil && self.start != nil && self.end != nil && !self.strains.empty?
      return true
    else
      return false
    end
  end
  
  def region_complete?
    if self.chromosome != nil && self.start != nil && self.end != nil # && (self.end - self.start).abs <= 20000000
      return true
    else
      return false
    end
  end
  
  def region_has_data?(include_snps,snp_count, include_microsats, microsat_count)
    has_data = true
    total_markers = 0
    
    total_markers = total_selected_markers(include_snps,snp_count, include_microsats, microsat_count)
    
    if total_markers <= 0
      has_data = false
    end
    
    if total_markers > 400
      has_data = false
    end
    
    return has_data
    
  end
  
  def total_selected_markers(include_snps, snp_count, include_microsats, microsat_count)
    total_markers = 0
    
    if include_snps
      total_markers += snp_count
    end
    
    if include_microsats
      total_markers += microsat_count
    end
    
    return total_markers
  end
  
end
