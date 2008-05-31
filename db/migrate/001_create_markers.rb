class CreateMarkers < ActiveRecord::Migration
  def self.up
    create_table :markers do |t|
      t.column :symbol, :string
      t.column :marker_type, :string
      t.column :rgd_id, :string             # RGD ID for this marker
      t.column :dbsnp_id, :string           # dbSNP id for this marker (SNP)
      t.column :dbsts_id, :string           # dbSTS id for this marker (SSLP)
      t.column :target_allele, :string      # A/G for SNPs, not valid for SSLPS
      t.column :number_of_alleles, :integer # 2 for SNPs, 6-13 for SSLPs
      t.column :sequence, :text             # sequence for this marker
      t.column :bn_genotype, :string          # expected SNP genotype in BN
    end
    
    add_index :markers, :rgd_id
  end

  def self.down
    remove_index :markers, :rgd_id
    drop_table :markers
  end
end
