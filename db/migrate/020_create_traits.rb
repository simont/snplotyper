class CreateTraits < ActiveRecord::Migration
  def self.up
    create_table :traits do |t|
      t.column :code, :string
      t.column :name, :string
      t.column :description, :string
      t.column :units, :string
    end
  end

  def self.down
    drop_table :traits
  end
end
