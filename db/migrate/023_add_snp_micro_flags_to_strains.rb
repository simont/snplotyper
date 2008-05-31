class AddSnpMicroFlagsToStrains < ActiveRecord::Migration
  def self.up
    add_column :strains, :microsatellite_count, :integer, :default => 0
    add_column :strains, :snp_count, :integer, :default => 0
    

    # Go through all the genotype data, counting each on to see if its a SNP
    Strain.find(:all).each do |str|
      snp_count = 0
      microsatellite_count = 0
      puts "Checking marker count for #{str.symbol}"
      next unless str.snp_count == 0 && str.microsatellite_count == 0
      puts "Processing #{str.symbol}"
      str.genotypes.each do |g|
        if g.marker.class.to_s == "Snp" && g.genotype_allele != 'NN'
          snp_count += 1
        elsif g.marker.class.to_s == "Microsatellite" && g.size != nil
          microsatellite_count += 1
        end
      end
      str.snp_count = snp_count
      str.microsatellite_count = microsatellite_count
      str.save
    end

  end

  def self.down
    remove_column :strains, :microsatellite_count
    remove_column :strains, :snp_count
  end
end
