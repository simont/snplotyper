class SelectedStrain < ActiveRecord::Base
  belongs_to :analysis
  belongs_to :strain
  acts_as_list :scope => :analysis
  
  def is_group2?
    if self.analysis_group && self.analysis_group == 2
      return true
    else
      return false
    end
  end
  
  def is_group1?
    if self.analysis_group && self.analysis_group == 1
      return true
    elsif self.analysis_group == nil
      return true
    else
      return false
    end
  end
end
