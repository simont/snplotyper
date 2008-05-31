class CreateAnalyses < ActiveRecord::Migration
  def self.up
    create_table :analyses do |t|
      t.column :chromosome, :string
      t.column :start, :integer
      t.column :end, :integer
      t.column :taxon_id, :integer
    end
    
    create_table :selected_strains do |tt|
      tt.column :analysis_id, :integer
      tt.column :strain_id, :integer
      tt.column :position, :integer
    end
  end

  def self.down
    drop_table :analyses
    drop_table :selected_strains
  end
end
