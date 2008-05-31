class CreateTraitMeasurements < ActiveRecord::Migration
  def self.up
    create_table :trait_measurements do |tt|
      tt.column :strain_id, :integer
      tt.column :trait_id, :integer
      tt.column :value, :float
    end
  end

  def self.down
    drop_table :trait_measurements
  end
end
