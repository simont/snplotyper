class CreatePanels < ActiveRecord::Migration
  def self.up
    create_table :panels do |t|
      t.column :name, :string
      t.column :description, :text
      t.column :taxon_id, :integer
      t.column :manufacturer, :string
      t.column :manufacturers_url, :string
    end
    
    # Insert the initial Rat SNP kit information from Affy
    p = Panel.new(
    :name => 'Rat Panel 1 5K SNP Kit',
    :description => '(From Affy) 5000 SNPs originally generated as a custom panel for a private researcher. Now available as a standard product albeit with limited additional information',
    :taxon_id => 10116,
    :manufacturer => 'Affymetrix',
    :manufacturers_url => 'http://www.affymetrix.com/products/reagents/specific/application_specific.affx'
    )
    p.save
    
  end

  def self.down
    drop_table :panels
  end
end
