class HaploviewController < ApplicationController
  
  require 'tempfile'
  
  # map.data 'data/:tmp_dir/:chunk_number/:file', :controller => 'haploview', :action => 'show_files'
  
  def show_files
    
      temp_dir = params[:tmp_dir]
      chunk = params[:chunk_number]
      file = params[:file]
      
      # redirect_to "/data/#{temp_dir}/#{chunk}/#{file}"
      
      # send_data compress(@text_output),
      #       :content_type => "application/x-gzip",
      #       :filename => @list.name.gsub(' ','_') + ".txt.gz"
      File.exists? "#{RAILS_ROOT}/public/data/#{temp_dir}/#{chunk}/#{file}"
      if file =~ "\.PNG$"
        send_file "#{RAILS_ROOT}/public/data/#{temp_dir}/#{chunk}/#{file}", :type => 'image/png', :disposition => 'inline'
      else
        send_file "#{RAILS_ROOT}/public/data/#{temp_dir}/#{chunk}/#{file}", :disposition => 'inline'
      end
    
  end
  
  
  # Creates a text file containing the genotype data of the region/subregion concerned
  # Pass in a list of markers from the region, then go and get the genotypes associated with those markers
  def create_haploview_genotype_file(marker_list,strain_list, genotype_list,dir_name,chunk_file_name, haploview_params)

    
    random_number = rand(100000)
    @tmp_file = "haploview_tmp_#{dir_name}"
    
    analysis_path = create_analysis_directories("#{RAILS_ROOT}/public", @tmp_file)
    chunk_files_path = create_analysis_chunk_directory(analysis_path,"chunk_#{chunk_file_name}")
    genotype_file = open("#{chunk_files_path}/#{chunk_file_name}_genotypes.hmp",'w') do |file|
      file.print "rs# SNPalleles chrom pos strand genome_build center protLSID assayLSID panelLSID QC_code "
      strain_symbols = Array.new
      strain_list.each do |s|
        # Haploview requres that strain names begin with NA...
        if s.symbol !~ /^NA/
          strain_symbols << "NA#{s.symbol}"
        else
          strain_symbols << s.symbol
        end
        
      end
      file.puts strain_symbols.join(' ')
      marker_list.each do |m| 
        file.print "#{m.symbol} #{m.target_allele} #{m.map_positions[0].chromosome_label} #{m.map_positions[0].start.to_i} + #{m.map_positions[0].map.name} center protlsid assaylsid panellsid QC+ "
        # file.puts strain_list
        genotypes_by_strain = Hash.new
        genotype_list[m].each do |g|
          genotypes_by_strain[g.strain_id] = g
        end

        strain_list.each do |s|
          g = genotypes_by_strain[s.id]
          file.print "#{genotypes_by_strain[s.id].genotype_allele.strip}\s"
        end
        file.print "\n" # end of line for this marker and its genotypes
      end
    end
    
    batch_file = open("#{chunk_files_path}/#{chunk_file_name}_genotypes.batch",'w') do |file|
      file.puts "#{chunk_files_path}/#{chunk_file_name}_genotypes.hmp"
      file.puts "# java -jar /Applications/Haploview.jar -n -batch #{chunk_files_path}/#{chunk_file_name}_genotypes.batch -minGeno 0.75 -hwcutoff 0.001 -maxMendel 1 -minMAF 0.05 -compressedpng"
    end
    Dir.chdir("#{chunk_files_path}")
    tagger_params = ""
    if haploview_params["tagger"] == "1"
      tagger_params = "-aggressiveTagging " if haploview_params["aggressiveTagging"]
      tagger_params << "-tagrsqcutoff #{haploview_params["tagrsqcutoff"]} -taglodcutoff #{haploview_params["taglodcutoff"]}"
    end
   @results = system("java -Xms256m -Xmx512m -jar /Applications/Haploview.jar -n -batch #{chunk_file_name}_genotypes.batch -minGeno #{haploview_params["minGeno"]} -hwcutoff 0.001 -maxMendel 1 -minMAF 0.05 -compressedpng #{tagger_params}")
    
    return "#{@tmp_file}/chunk_#{chunk_file_name}/#{chunk_file_name}"
  end
  
  # Creates directory and subdirectory structures for analysis results
  # data_path is the path to the data directory, typicaly: RAILS_ROOT/public/data
  
  def create_analysis_directories(data_path,analysis_name)
    
    # Check data_path exists
    # raise "Data directory does not exist" unless File.exists? data_path
    if !File.exists? "#{data_path}/data"
      begin
        # Create the data dir if its not there already
        FileUtils.mkdir("#{data_path}/data")
      rescue Exception => e
        $LOG.warn("Error: #{e.message}")
      end
    end
    
    raise "Data directory is not writeable" unless File.writable? data_path
    
    if !File.exists? "#{data_path}/data/#{analysis_name}"
      begin
        # Create the analysis dir if its not there already
      FileUtils.mkdir("#{data_path}/data/#{analysis_name}") 
      rescue Exception => e
        $LOG.warn("Error: #{e.message}")
      end
    end
    
    raise "Analysis directory is not writeable" unless File.writable? "#{data_path}/data/#{analysis_name}"
    
    return  "#{data_path}/data/#{analysis_name}"
  end
  
  # Create subdirectory for a chunk of a region
  
  def create_analysis_chunk_directory(chunk_path, chunk_name)
    
    raise "Data Chunk directory #{chunk_path }is not writeable" unless File.writable? chunk_path
    
    if !File.exists? "#{chunk_path}/#{chunk_name}"
      begin
        FileUtils.mkdir("#{chunk_path}/#{chunk_name}")
      rescue Exception => e
        $LOG.warn("Error: #{e.message}")
      end
    end
    
  end
  
  
  
  # Creates batch file with list(s) of files to be analyzed via the commandline
  # Version of haploview
  
  def create_haploview_batch_file
    
  end
  
end
