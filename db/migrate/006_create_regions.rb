class CreateRegions < ActiveRecord::Migration
  def self.up
    create_table :regions do |t|
      t.column :user_id, :integer
      t.column :title, :integer
      t.column :chromosome_index, :integer
      t.column :map_id, :integer
      t.column :flank1_marker_id, :integer
      t.column :flank2_marker_id, :integer
    end
    
    # create the formal links to the marker table
    add_index :regions, :flank1_marker_id
    add_index :regions, :flank2_marker_id
    # execute "ALTER TABLE regions ADD CONSTRAINT f1_marker_key FOREIGN KEY (flank1_marker_id) REFERENCES markers"
    # execute "ALTER TABLE regions ADD CONSTRAINT f2_marker_key FOREIGN KEY (flank2_marker_id) REFERENCES markers
    
  end

  def self.down
    drop_table :regions
  end
end
