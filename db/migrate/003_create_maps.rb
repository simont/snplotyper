class CreateMaps < ActiveRecord::Migration
  def self.up
    create_table :maps do |t|
      t.column :name, :string
      t.column :map_type, :string # RH, genetic, physical
      t.column :version, :string # 3.1, RH 3.4
      t.column :units, :string # bp, cM, cR, etc.
    end
    
    m = Map.new(
      :name  => "RGSC v3.4",
      :map_type => "genome",
      :version => "3.4",
      :units => "bp"
    )
    m.save
    
    m2 = Map.new(
      :name  => "ncbi_b35",
      :map_type => "genome",
      :version => "35",
      :units => "bp"
    )
    m2.save
  end

  def self.down
    drop_table :maps
  end
end
