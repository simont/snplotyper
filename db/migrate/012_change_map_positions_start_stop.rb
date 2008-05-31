class ChangeMapPositionsStartStop < ActiveRecord::Migration
  def self.up
    remove_column :map_positions, :start
    remove_column :map_positions, :end
    add_column :map_positions, :start, :integer
    add_column :map_positions, :end, :integer
  end
 
  def self.down
    remove_column :map_positions, :start
    remove_column :map_positions, :end
    add_column :map_positions, :start, :float
    add_column :map_positions, :end, :float
  end
end