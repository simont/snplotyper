class CreateGenotypes < ActiveRecord::Migration
  def self.up
    create_table :genotypes do |t|
      t.column :marker_id, :integer
      t.column :strain_id, :integer
      t.column :is_het, :boolean          # is this a heterozygote at this position
      t.column :size, :integer            # for microsatellites
      t.column :genotype_code, :integer   # 0,1,2,5,6 for SNPs
      t.column :genotype_allele, :string  # actual allele base observed
    end
    
    add_index :genotypes, :marker_id
    add_index :genotypes, :strain_id
  end

  def self.down
    drop_table :genotypes
  end
end
