class AddCreatedUpdatedToAnalysis < ActiveRecord::Migration
  def self.up
    add_column :analyses, :created_at, :datetime
    add_column :analyses, :updated_at, :datetime
    
    Analysis.find(:all).each do |a|
      a.update_attribute('created_at', Time.now)
      a.update_attribute('updated_at', Time.now)
    end
    
  end

  def self.down
    remove_column :analyses, :created_at
    remove_column :analyses, :updated_at
  end
end
