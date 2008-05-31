class AddMappableToMappos < ActiveRecord::Migration
  def self.up
    add_column :map_positions, :mappable_id, :integer
    add_column :map_positions, :mappable_type, :string
    remove_column :map_positions, :marker_id
  end

  def self.down
    remove_column :map_positions, :mappable_id
    remove_column :map_positions, :mappable_type
    add_column :map_positions, :marker_id, :integer
  end
end
