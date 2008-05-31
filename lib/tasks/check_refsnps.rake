desc 'Quick routine to check RefSNP ids for Rat SNPs'
task :check_refsnps => :environment do
  # Your code goes here
  puts "Checking for refsnp file"
  file_name = "#{RAILS_ROOT}/test/mocks/STAR_4_STRAIN_SNP.txt"

  match_count = multimatch_count = nomatch_count = 0
  matched_markers = []

  File.open(file_name,"r") do |file|
    
    while (line = file.gets)

      line.chomp!
      ens,chr,loc,allele,type,str = line.split(/\t/)
      
      loc_match = MapPosition.find_all_by_chromosome_number_and_start_and_map_id(chr,loc,1)
      if loc_match != nil && loc_match.size == 1
        marker = Snp.find_by_id_and_marker_type(loc_match[0].mappable_id,'Snp')
        # puts "Found match: #{marker.symbol} = #{ens}"
        match_count += 1
        matched_markers << marker
      elsif loc_match.size > 1
        puts "Multiple location matches for #{ens}"
        multimatch_count += 1
      else
        # puts "No match for #{rs}"
        nomatch_count += 1
      end
    end
  end
  
  puts "Mathched #{matched_markers.size} SNPs in the database"
  puts "Matched #{match_count} ENSSNP Ids"
  puts "No match for  #{nomatch_count} ENSSNP Ids"
  puts "Matched #{multimatch_count} ENSSNP Ids to multiple locations"
  
end