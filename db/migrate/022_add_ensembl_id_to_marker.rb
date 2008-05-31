class AddEnsemblIdToMarker < ActiveRecord::Migration
  def self.up
    add_column :markers, :ensembl_id, :string
    add_index(:markers, :ensembl_id)
    add_index(:markers, :symbol)
  end

  def self.down
    remove_column :markers, :ensembl_id
    remove_index(:markers, :ensembl_id)
    remove_index(:markers, :symbol)
  end
end
