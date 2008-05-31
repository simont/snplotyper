desc 'Quick routine to match STAR SNP symbols to corresponding Ensembl SNP symbols'

task :update_ensembl_ids => :environment do
  # Your code goes here
  puts "Checking for STAR->Ensembl file"
  file_name = "#{RAILS_ROOT}/test/mocks/star_id_to_ensembl_id.txt"

  match_count = multimatch_count = nomatch_count = 0
  matched_markers = []

  File.open(file_name,"r") do |file|
    
    while (line = file.gets)

      line.chomp!
      star_id,ensembl_id = line.split(/\t/)
      
      marker_match = Snp.find_all_by_symbol(star_id)
      if marker_match != nil && marker_match.size == 1
        # puts "Found match: #{marker_match[0].symbol} = #{ens}"
        match_count += 1
        matched_markers << marker_match[0]
        marker_match[0].ensembl_id = ensembl_id
        marker_match[0].symbol = ensembl_id # make this the symbol for now, also
        marker_match[0].save
      else
        # puts "**** No match for #{star_id}"
        nomatch_count += 1
      end
    end
  end
  
  puts "Matched #{matched_markers.size} STAR SNPs in the database"
  puts "No match for  #{nomatch_count} STAR Ids from the ENSEMBL db"
  
  no_ensembl = Snp.find_all_by_ensembl_id(nil).size
  puts "There are  #{no_ensembl} SNPs remaining in the database lacking ENSEMBL IDs"
  
end