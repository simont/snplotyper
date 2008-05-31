class AddPrimaryAndGroupsToAnalysis < ActiveRecord::Migration
  def self.up
    add_column :analyses, :primary_strain_id, :integer
    add_column :selected_strains, :analysis_group, :integer
    
    #put all the current selected strains into group 1 for now
    SelectedStrain.find(:all).each do |s|
      s.update_attribute('analysis_group', 1) 
    end
  end

  def self.down
    remove_column :analyses, :primary_strain_id
    remove_column :selected_strains, :analysis_group
  end
end
