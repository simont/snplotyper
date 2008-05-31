class AddPolymorphicColsToGenotypes < ActiveRecord::Migration
  def self.up
    add_column :genotypes, :genotypable_id, :integer
    add_column :genotypes, :genotypable_type, :string
    remove_column :genotypes, :marker_id
  end

  def self.down
    remove_column :genotypes, :genotypable_id
    remove_column :genotypes, :genotypable_type
    add_column :genotypes, :marker_id, :integer
  end
end
