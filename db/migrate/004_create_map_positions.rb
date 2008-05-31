class CreateMapPositions < ActiveRecord::Migration
  def self.up
    create_table :map_positions do |t|
      t.column :map_id, :integer
      t.column :marker_id, :integer
      t.column :chromosome_number, :integer # 21
      t.column :chromosome_label, :string # X
      t.column :start, :float # Float to allow for RH maps, etc.
      t.column :end, :float   # Float to allow for RH maps, etc.
      t.column :strand, :integer
    end
    add_index :map_positions, :map_id
    add_index :map_positions, :marker_id
  end

  def self.down
    remove_index :map_positions, :marker_id
    remove_index :map_positions, :map_id
    drop_table :map_positions
  end
end
