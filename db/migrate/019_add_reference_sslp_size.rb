class AddReferenceSslpSize < ActiveRecord::Migration
  def self.up   
   add_column :markers, :reference_sslp_size, :integer
   bn_strain = Strain.find_by_symbol('BN/SsNHsd')
   
   sslps = Microsatellite.find(:all)
   sslps.each do |m|
   bn_allele = m.genotypes.find_by_strain_id(bn_strain.id)
     if bn_allele != nil
       m.update_attribute('reference_sslp_size', bn_allele.size)
     end
   end
  end

  def self.down
    remove_column :markers, :reference_sslp_size
  end
end
