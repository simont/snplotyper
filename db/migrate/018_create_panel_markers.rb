class CreatePanelMarkers < ActiveRecord::Migration
  def self.up
    create_table :panel_markers do |t|
      t.column :marker_id, :integer
      t.column :panel_id, :integer
    end
  end

  def self.down
    drop_table :panel_markers
  end
end
