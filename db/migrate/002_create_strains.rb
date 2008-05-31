class CreateStrains < ActiveRecord::Migration
  def self.up
    create_table :strains do |t|
      t.column :symbol, :string       # The strain and substrain symbol
      t.column :mdc_id, :string       # MDC Id for strain
      t.column :cng_id, :string       # CNG ID for strain
      t.column :rgd_id, :string       # RGD ID for strain
      t.column :origin, :string       # country of origin for the rat
      t.column :origin_lab, :string   # lab that sent the rat to be genotyped
      t.column :source_tissue, :string #spleen, etc. from strain
    end
    
    add_index :strains, :mdc_id
    add_index :strains, :rgd_id
  end

  def self.down
    remove_index :strains, :mdc_id
    remove_index :strains, :rgd_id
    drop_table :strains
  end
end
