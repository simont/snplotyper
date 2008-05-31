class AddPopulationIdToStrains < ActiveRecord::Migration
  def self.up
    add_column :strains, :population_id, :integer
  end

  def self.down
    remove_column :strains, :population_id
  end
end
