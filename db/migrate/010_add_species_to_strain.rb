class AddSpeciesToStrain < ActiveRecord::Migration
  def self.up
    add_column :strains, :taxon_id, :integer
  end

  def self.down
    remove_column :strains, :taxon_id
  end
end
