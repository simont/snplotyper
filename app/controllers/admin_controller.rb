class AdminController < ApplicationController

  @@strain_cache = Array.new

  def load_strains

    if request.post?
      if params[:inputfile].respond_to? :readlines
        @file_contents = {"protein_count" => 0,
          "verbose" => "Detailed Report:<br>\n",
          "errors" => "Errors:<br>\n"
        }

        file_array =  params[:inputfile].readlines
        file_array.each do |f|
          next if f =~ /^#/ # ignore lines that start with a hash - comments
          f.strip! # remove the annoying whitespace

          data = f.split(/\t/)
          s = Strain.new(
          :mdc_id  => data[0],
          :cng_id  => data[1],
          :symbol  => data[2],
          :origin  => data[3],
          :origin_lab => data[4]
          )

          if s.save
            @file_contents['verbose'] << "Created new strain for #{s.symbol}</br>"
          else
            @file_contents['verbose'] << "** Error saving new strain for #{data[2]}"
          end

        end
        @flash['notice'] = 'File loaded successfully'
      else
        @flash['error'] = 'Problems loading file...'
      end
    end #request.post?

  end

  def load_snps
    if request.post?
      if params[:inputfile].respond_to? :readlines
        @file_contents = {
          "snp_count" => 0,
          "genotype_count"  => 0,
          "verbose" => "Detailed Report:<br>\n",
          "errors" => "Errors:<br>\n",
          "incomplete_data_error_count" => 0
        }

        column_headings = []
        @format = params[:snp_format]
        if params[:snp_format] == "hapmap_genotype"

          file_array =  params[:inputfile].readlines
          file_array.each do |f|

            #File.open(params[:inputfile],"r") do |file|
            # while (f = file.gets)
            next if f =~ /^#/ # ignore lines that start with a hash - comments
            f.strip!  # remove any whitespace, linefeeds, etc.

            # if this line has the column headings, extract and do the next line
            if f =~ /^rs#/
              column_headings = f.split(/\s/)
              next
            end

            # Split the hapmap file based on spaces
            snp_data = f.split(/\s/)

            load_hapmap_snp_data(column_headings,snp_data)

            #end # end of while loop
          end # of File.open
        elsif params[:snp_format] == "sslp_allele_data"
          file_array =  params[:inputfile].readlines
          file_array.each do |f|

            #File.open(params[:inputfile],"r") do |file|
            # while (f = file.gets)
            next if f =~ /^#/ # ignore lines that start with a hash - comments
            f.strip!  # remove any whitespace, linefeeds, etc.

            # if this line has the column headings, extract and do the next line
            if f =~ /^RGD/
              column_headings = f.split(/\t/)
              next
            end

            # Split the biomart dump file on tabs
            sslp_data = f.split(/\t/)

            load_rgd_sslp_data(column_headings,sslp_data)

            #end # end of while loop
          end # of File.open
        elsif
          params[:snp_format] == "hjj_sslp_snp_with_traits"
          file_array =  params[:inputfile].readlines
          process_str_file(file_array)
        else
          file_array =  params[:inputfile].readlines
          file_array.each do |f|
            next if f =~ /^#/ # ignore lines that start with a hash - comments
            f.strip!  # remove any whitespace, linefeeds, etc.
            
            # if this line has the column headings, extract and do the next line
            if f =~ /^a1_External_ID/
              column_headings = f.split(/\t/)
              next
            end
            
            snp_data = f.split(/\t/)

            if column_headings.size == snp_data.size
              @file_contents['snp_count'] += load_mdc_snp_data(column_headings,snp_data)
            else
              # There should be the same number of data points in the SNP data row as in the column headings
              # unless something bad is going on....
              @file_contents['incomplete_data_error_count'] += 1
            end

          end
        end
        if @file_contents['incomplete_data_error_count'] > 0
          flash[:error] = "Incomplete data - marker data has different number of columns than header row for #{@file_contents['incomplete_data_error_count']} markers!"
        else
          flash[:notice] = 'File processed successfully'
        end
      else
        flash[:error] = 'Problems loading SNP file, is it plain text format?'
      end# params[:inputfile].respond_to? :readlines
    end#request.post?
  end

  # def fix_strains
  #     
  #     all_strains = Strain.find(:all)
  #     all_strains.each do |s|
  #       s.update_attribute('origin_lab',s.origin_lab.strip) if s.origin_lab != nil
  #     end
  #   end

  def process_str_file(file_array)
    column_headings = []
    file_array.each do |f|

      #File.open(params[:inputfile],"r") do |file|
      # while (f = file.gets)
      next if f =~ /^#/ # ignore lines that start with a hash - comments
      f.strip!  # remove any whitespace, linefeeds, etc.

      # if this line has the column headings, extract and do the next line
      if f =~ /^Order/
        column_headings = f.split(/\t/)
        next
      end

      # Split the biomart dump file on tabs
      the_data = f.split(/\t/)

      case the_data[2]
      when 'TRAIT'
        load_hjj_trait_data(column_headings,the_data)
      when 'SNP'
        load_hjj_snp_data(column_headings,the_data)
      when 'STR'
        load_hjj_str_data(column_headings,the_data)
      end

      #end # end of while loop
    end # of File.open
    
  end
  
  def load_hjj_str_data(column_headings,the_data)
    sslps_loaded = 0
    sslp = Microsatellite.find_by_symbol(the_data[1])
    if sslp == nil
      sslp = Microsatellite.new(
      :symbol => the_data[1],
      :rgd_id => the_data[0]
      )
    end
    
    chr_text = the_data[3]
    bp = the_data[4].gsub!(/\"/,'') 
    bp = the_data[4].gsub!(/,/,'')

    if sslp.save
      the_map = Map.find(1) # TODO make this more robust, assumes only one map - not realistic
      create_map_position(sslp,the_map,chr_text,the_data[4], the_data[4])
      sslps_loaded += 1
    end
    
    ##### Load SSLP allele data
    
    alleles = the_data[6..226]   # 500 is arbitrary large number, larger than number of columns
      strain_cache = []       # store the strain objects after we've first got them, save db access

      alleles.each_with_index do |allele, i|
        # $LOG.warn("Allele for strain: #{column_headings[i+6]}")
        # find the strain appropriate to this column
        strain = @@strain_cache[i]
        if strain == nil
        strain = Strain.find_by_symbol(column_headings[i+6])

         if strain == nil
            strain = Strain.create(
              :symbol => column_headings[i+6],
              :taxon_id => 10116
              )
          end
           @@strain_cache[i] = strain
        end

        if strain != nil # wasnt found in database

          is_het = false
          allele1, allele2 = allele.split(/\s/)
          allele_size = allele1 # default value
          if allele1 != allele2
            is_het = true
          end
          
          geno = Genotype.new(
          :genotypable => sslp,
          :strain => strain,
          :is_het => is_het,
          :size => allele_size
          )

          geno.save!
          #  puts "Created genotype: #{geno.id} strain: #{strain.symbol}"
        end
        
      end#alleles.each loop
    
    # Need to get the BN/SsNHsd genotype, if it exists and use that to set the reference genotype value
    bn_strain = Strain.find_by_symbol('BN/N phenol')
    bn_allele = sslp.genotypes.find_by_strain_id(bn_strain.id)
    if bn_allele != nil
      sslp.update_attribute('reference_sslp_size', bn_allele.size)
    end
    
    
  end

  def load_hjj_snp_data(column_headings,the_data)
    
    snp = Snp.find_by_symbol(the_data[1])
    if snp == nil
      snp = Snp.new(
      :symbol => the_data[1],
      :target_allele => the_data[5],
      :number_of_alleles => 2,
      :dbsnp_id => the_data[1]
      )
    end

    chr_text = the_data[3]
    bp = the_data[4].gsub!(/\"/,'') 
    bp = the_data[4].gsub!(/,/,'') 

    if snp.save
      the_map = Map.find(1)
      create_map_position(snp,the_map,chr_text,bp, bp)
    end
    
    alleles = the_data[6..226]  # 500 is arbitrary large number, larger than number of columns

    alleles.each_with_index do |allele, i|
        # find the strain appropriate to this column
        strain = @@strain_cache[i]
        if strain == nil
        strain = Strain.find_by_symbol(column_headings[i+6])

         if strain == nil
            strain = Strain.create(
              :symbol => column_headings[i+6],
              :taxon_id => 10116
              )
          end
           @@strain_cache[i] = strain
        end

      if strain != nil # was found in database

        is_het = false
        genotype_allele = allele # default value

        allele1,allele2 = snp.target_allele.split('/')

        case allele
        when '1'
          is_het = true
          genotype_code = 1
          genotype_allele = "#{allele1}#{allele2}"
        when '0'
          is_het = false
          genotype_code = 0
          genotype_allele = "#{allele1}#{allele1}"
        when '2'
          is_het = false
          genotype_code = 2
          genotype_allele = "#{allele2}#{allele2}"
        when '5'
          is_het = false
          genotype_code = 5
          genotype_allele = "NN"
        else
          is_het = false
          genotype_code = 6
          genotype_allele = "NN"
        end

        geno = Genotype.new(
        :genotypable => snp,
        :strain => strain,
        :is_het => is_het,
        :genotype_code => genotype_code,
        :genotype_allele => genotype_allele
        )

        geno.save!
        #  puts "Created genotype: #{geno.id} strain: #{strain.symbol}"
      end
    end#alleles.each loop
    
    
  end


  def load_hjj_trait_data(column_headings,the_data)
    
    # Check to see if trait already exists
    trait = Trait.find_by_code(the_data[1])
    if trait == nil
      trait = Trait.create(
        :code => the_data[1],
        :name => the_data[1]
      )
    end
    
    strain_trait_values = the_data[6..226]
    strain_trait_values.each_with_index do |value,i|
      # find the strain appropriate to this column
      strain = @@strain_cache[i]
      if strain == nil
      strain = Strain.find_by_symbol(column_headings[i+6])

       if strain == nil
          strain = Strain.create(
            :symbol => column_headings[i+6],
            :taxon_id => 10116
            )
        end
         @@strain_cache[i] = strain
      end
      

      if strain != nil
        trait_value = TraitMeasurement.create(
        :strain_id => strain.id,
        :trait_id => trait.id,
        :value => strain_trait_values[i]
        )
        
      end
    end
  end


  def load_rgd_sslp_data(column_headings,sslp_data)
    sslps_loaded = 0
    
    # We only want to load Rat SSLPs from an RGD file so if this is not rat, ignore it
    # Also, need complete mapping data otherwise we'll skip for now
    if sslp_data[2] != 'rat' || sslp_data[3] == nil || sslp_data[4] == "0" || sslp_data[5] == "0"
      return sslps_loaded
    end
    
    # $LOG.warn("Columns: #{column_headings}")
    
    sslp = Microsatellite.find_by_symbol(sslp_data[1])
    if sslp == nil
      sslp = Microsatellite.new(
      :symbol => sslp_data[1],
      :rgd_id => sslp_data[0]
      )
    end
    
    chr_text = sslp_data[3]

    if sslp.save
      the_map = Map.find(1) # TODO make this more robust, assumes only one map - not realistic
      create_map_position(sslp,the_map,chr_text,sslp_data[4], sslp_data[5])
      sslps_loaded += 1
    end
    
    ##### Load SSLP allele data
    
     alleles = sslp_data[6..sslp_data.size]  # 500 is arbitrary large number, larger than number of columns
      strain_cache = []       # store the strain objects after we've first got them, save db access

      alleles.each_with_index do |allele, i|
        # $LOG.warn("Allele for strain: #{column_headings[i+6]}")
        strain = strain_cache[i]
        if strain == nil
          # find the strain appropriate to this column
          strain = Strain.find_by_symbol(column_headings[i+6])
          if strain == nil
            $LOG.warn("Creating new strain: #{column_headings[i+6]}")
            strain = Strain.create(
            :symbol => column_headings[i+6],
            :taxon_id => 10116
            )
          end
          strain_cache[i] = strain # save for subsequent markers
        end

        if strain != nil # wasnt found in database

          is_het = false
          allele_size = allele # default value
          
          geno = Genotype.new(
          :genotypable => sslp,
          :strain => strain,
          :is_het => is_het,
          :size => allele_size
          )

          geno.save!
          
          if allele_size != nil
            new_strain_microsat_count = strain.microsatellite_count + 1
            Strain.update(strain.id, {:microsatellite_count => new_strain_microsat_count})
            # puts "Created genotype: #{geno.id} strain: #{strain.symbol} allele: #{allele}"
          end
        end
        
      end#alleles.each loop
    
    # Need to get the BN/SsNHsd genotype, if it exists and use that to set the reference genotype value
    bn_strain = Strain.find_by_symbol('BN/SsNHsd')
    bn_allele = sslp.genotypes.find_by_strain_id(bn_strain.id)
    if bn_allele != nil
      sslp.update_attribute('reference_sslp_size', bn_allele.size)
    end
    
    ##### End of Load SSLP Allele data
    
    return sslps_loaded
    
  end
  
  

  def create_map_position(marker, map, chr, start, stop)
    MapPosition.create(
    :mappable => marker,
    :map => map,
    :chromosome_number => CHR_NUMBERS[chr],
    :chromosome_label => chr,
    :start => start,
    :end => stop
    )
  end
  

  # creates new hapmap snp & genotype entries for a given line from a hapmap dataset

  def load_hapmap_snp_data(column_head_array, hapmap_row_array)

    snps_loaded = 0

    # Need to check that a given SNP exists or not, if not, create new entry
    # snp symbol is the rs# from a hapmap file
    snp = Snp.find_by_symbol(hapmap_row_array[0])
    if snp == nil
      snp = Snp.new(
      :symbol => hapmap_row_array[0],
      :target_allele => hapmap_row_array[1],
      :number_of_alleles => 2,
      :dbsnp_id => hapmap_row_array[0]
      )
    end

    chr_text = hapmap_row_array[2]
    chr_text.gsub!(/^chr/i,'') # remove the chr at the start of the chromosome number, make this case insensitive as it seems to vary in hapmap files

    if snp.save
      the_map = Map.find_by_name(hapmap_row_array[5])
      create_map_position(snp,the_map,chr_text,hapmap_row_array[3], hapmap_row_array[3])
      snps_loaded += 1
    end

    # SNP should exist at this point, lets load the genotype data

    alleles = hapmap_row_array[11..hapmap_row_array.size]  # 500 is arbitrary large number, larger than number of columns
    strain_cache = []       # store the strain objects after we've first got them, save db access

    alleles.each_with_index do |allele, i|

      strain = strain_cache[i]
      if strain == nil
        # find the strain appropriate to this column
        strain = Strain.find_by_symbol(column_head_array[i+11])
        if strain == nil
          strain = Strain.create(
          :symbol => column_head_array[i+11],
          :taxon_id => 9606
          )
        end
        strain_cache[i] = strain # save for subsequent markers
      end

      if strain != nil # wasnt found in database

        is_het = false
        genotype_allele = allele # default value

        allele1,allele2 = snp.target_allele.split('/')

        case allele
        when "#{allele1}#{allele2}"
          is_het = true
          genotype_code = 1
        when "#{allele2}#{allele1}"
          is_het = true
          genotype_code = 1
        when "#{allele1}#{allele1}"
          is_het = false
          genotype_code = 0
        when "#{allele2}#{allele2}"
          is_het = false  
          genotype_code = 2 
        when "NN"
          is_het = false
          genotype_code = 5
        else
          is_het = false
          genotype_code = 6
        end

        geno = Genotype.new(
        :genotypable => snp,
        :strain => strain,
        :is_het => is_het,
        :genotype_code => genotype_code,
        :genotype_allele => genotype_allele
        )

        geno.save!
        #  puts "Created genotype: #{geno.id} strain: #{strain.symbol}"
      end
    end#alleles.each loop

    return snps_loaded
  end

  #####
  # MDC Rat strains already loaded via another action
  #####
  
  def load_mdc_snp_data(column_head_array, snp_data)
    snps_loaded = 0
    snp = Snp.find_by_symbol(snp_data[0])
    if snp == nil
      snp = Snp.new(
      :symbol => snp_data[0],
      :sequence => snp_data[3],
      :bn_genotype => snp_data[4],
      :target_allele => snp_data[5]
      )

      # location = MapPosition.new(
      #       :chromosome_label => snp_data[1],
      #       :chromosome_number => CHR_NUMBERS[snp_data[1]],
      #       :start => snp_data[2],
      #       :end => snp_data[2]
      #       )

      if snp.save
        the_map = Map.find(1)
        MapPosition.create(
        :mappable => snp,
        :map => the_map,
        :chromosome_number => CHR_NUMBERS[snp_data[1]],
        :chromosome_label => snp_data[1],
        :start => snp_data[2],
        :end => snp_data[2]
        )
        snps_loaded += 1
      end
    end

    # SNP should exist at this point, lets load the genotype data

    alleles = snp_data[7..500]  # 500 is arbitrary large number, larger than number of columns
    strain_cache = []       # store the strain objects after we've first got them, save db access

    alleles.each_with_index do |allele, i|

      strain = strain_cache[i]
      if strain == nil
        # find the strain appropriate to this column
        strain = Strain.find_by_mdc_id(column_head_array[i+7])
        if strain == nil
          
          # $LOG.warn(">>>>> >>>> New strain!!: #{column_head_array[i+7]}")
          
          strain = Strain.create(
          :symbol => column_head_array[i+7],
          :mdc_id => column_head_array[i+7],
          :taxon_id => 10116
          )
        end
        strain_cache[i] = strain # save for subsequent markers
      end

      if strain != nil # was found in database or created new

        is_het = false
        genotype_allele = '' # default value

        # For Rat, Allele 1 == BN, Allele 2 == other?
        allele1,allele2 = snp.target_allele.split('/')
        if snp.bn_genotype != allele1
          # Need to swap things around
          tmp1 = allele1
          tmp2 = allele2
          allele1 = tmp2
          allele2 = tmp1
        end


        # Translate the MDC data notation into genotype notation that is compatible
        # with other tools such as haploview

        case allele
        when '0'
          is_het = false
          genotype_allele = "#{allele1}#{allele1}"
          genotype_code = 0
        when '1'
          is_het = true
          genotype_allele = "#{allele1}#{allele2}"
          genotype_code = 1
        when '2'
          is_het = false
          genotype_allele = "#{allele2}#{allele2}"
          genotype_code = 2
        when '5'
          is_het = false
          genotype_allele = "#{allele2}#{allele2}"
          genotype_code = 5
        else
          is_het = false
          genotype_allele = "NN"
          genotype_code = 6
        end

        geno = Genotype.create(
        :genotypable => snp,
        :strain => strain,
        :is_het => is_het,
        :genotype_code => genotype_code,
        :genotype_allele => genotype_allele
        )
        
        if genotype_allele != 'NN'
          new_strain_snp_count = strain.snp_count + 1
          Strain.update(strain.id, {:snp_count => new_strain_snp_count})
        end
      end

    end
    return snps_loaded
  end

end


