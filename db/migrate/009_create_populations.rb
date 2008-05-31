class CreatePopulations < ActiveRecord::Migration
  def self.up
    create_table :populations do |t|
      t.column :symbol, :string
      t.column :name, :string
      t.column :description, :text
      t.column :species, :string
      t.column :taxon_id, :integer
    end
  end

  def self.down
    drop_table :populations
  end
end
