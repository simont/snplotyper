class MapController < ApplicationController
  require 'rubygems'
  require 'rvg/rvg'
  require 'open-uri'
  include Magick


  def list_parameters

    # used to indicate if all the appropriate values have been filled in
    # is set to false if anything is missing, this can then be used to
    # to activate/inactivate the submit button on the form to ensure
    # people submit correct information to the software.
    @form_complete = true
    @region_complete = true

    process_selection_params

    # if params[:region]['chromosome'] && params[:region]['chromosome'] != "0"
    if valid_params?('chromosome', params[:region]['chromosome'])
      @chromosome = params[:region]['chromosome']
    else
      @chromosome = "<span style='color: red;'>Not Selected</span>"
      @form_complete = false
      @region_complete = false
    end

    if valid_params?("start", params[:region]['start'])
      @start = params[:region]['start']
    else
      @start = "<span style='color: red;'>Not Selected</span>"
      @form_complete = false
      @region_complete = false
    end

    if valid_params?("end", params[:region]['end'])
      @stop = params[:region]['end']
    else
      @stop = "<span style='color: red;'>Not Selected</span>"
      @form_complete = false
      @region_complete = false
    end

    # if the region parameters are complete, check the number of SNPs in
    # this region so the user gets some quick feedback
    @snp_count = 0
    if @region_complete
      selected_map = params[:region]['map_id'] || 1
      map = Map.find(selected_map)
      @start
      @snp_count = map.count_on_chr_between_start_and_stop(@chromosome.to_i,@start.gsub(/,/,'').to_i,@stop.gsub(/,/,'').to_i)
      if @snp_count == 0
        @form_complete = false
      end
    end

    if !valid_params?("strains", params[:strain])
      # @strains = "<span style='color: red;'>Not Selected</span>"
      @form_complete = false
    end

    render :partial  => "list_parameters"
  end


  def valid_params?(param, value)

    # Set a flag to determine if this parameter's value is valid or not
    # if anything invalidates it during the course of the checks, this is set to false
    is_valid = true

    case param
    when "chromosome"
      if value == "0"
        is_valid = false
      end
      if value.empty?
        is_valid = false
      end

    when "start"
      if value.empty?
        is_valid = false
      end
      if value !~ /[1-9,]/
        is_valid = false
      end
    when "end"
      if value.empty?
        is_valid = false
      end
      if value !~ /[1-9,]/
        is_valid = false
      end
    when "strains"
      if value == nil
        is_valid = false
      elsif value.empty?
        is_valid = false
      end
    end

    return is_valid
  end

  def process_selection_params

    @chromosome = params[:region]['chromosome']
    @start = params[:region]['start'].gsub(/,/,'').to_i
    @stop = params[:region]['end'].gsub(/,/,'').to_i

    # @start.gsub(/,/,'').to_i
    

    # Compile the list of strains using the various strain selectors
    # and filters (Country and Lab) available on the form
    @strains = []
    @strain_list = Hash.new

    if params.has_key?(:origins)
      if params[:origin]['country'] == nil or params[:origin]['country'] == "0"
        @country = 'No'
      else
        @country = params[:origin]['country']
      end

      if params[:origin]['lab'] == nil or params[:origin]['lab'] == "0"
        @lab = 'No'
      else
        @lab = params[:origin]['lab']
      end
    end

    @removed_markers = []   # array to hold any markers removed because all data was missing

    all_strain_list = Strain.find(:all)

    all_strain_list.each do |str|
      if params.has_key?(:origins)
        if params[:origin]['country'] == '0' && params[:origin]['lab'] == '0' && (params[:strain] == nil or params[:strain].empty?)
          # nothing selected at all
          break
        end

        next if params[:origin]['country'] != '0' && str.origin != params[:origin]['country']
        next if params[:origin]['lab'] != '0' && str.origin_lab != params[:origin]['lab']
      end
      if params[:strain] != nil
        @strains << str if params[:strain][str.id.to_s] == '1'
        @strain_list[str.id.to_s] = str.symbol if params[:strain][str.id.to_s] == '1'
      else
        # at this point no individual strains selected, must have passed both country and lab filters
        # so add to the list...
        # @strains << str
        # @strain_list[str.id.to_s] = str.symbol
      end
    end

    # Sort the strains alphabetically for now
    @strains.sort! {|x,y| x.symbol <=> y.symbol }

  end

  # Action to display the standard haplotype report page, redirects to the select_region
  # action if the request is not a POST

  def haplotype_view

    if request.post?

      flash[:error] = ""

      # updated to include regex matching for commas also
      if params[:region]['start'].empty? || params[:region]['start'] !~ /[1-9,]/
        flash[:error] += "You must supply a valid start value!<br>"
      end

      if params[:region]['end'].empty? || params[:region]['end'] !~ /[1-9,]/
        flash[:error] += "You must supply a valid stop value!<br>"
      end

      if params[:region]['chromosome'] == '0' || params[:region]['chromosome'] !~ /[\dXY]/
        flash[:error] += "You must supply a valid chromosome value!<br>"
      end

      unless params.has_key?(:strain)
        flash[:error] += "You must select at least one strain!<br>"
      end

      if flash[:error] != ""
        redirect_to :action => 'select_region' and return
      end

      selected_map = params[:region]['map_id'] || 1
      @map = Map.find(selected_map)
      @markers = []

      process_selection_params

      # do the processing to get the data
      get_region_marker_data(@map.id, @chromosome, @start, @stop)

      # Filter to remove any markers that have no genotype data across the region

      marker_genotype_list = Hash.new


      $LOG.warn("Started with #{@markers.size} markers found on map #{@map.id} in region #{@chromosome}: #{@start}-#{@stop}")

      if params[:strainfilter] != nil
        # Create a duplicate copy of @markers that we can iterate over
        # making changes to the parent copy of @markers as we go.
        # previously was deleting keys from Hash in the middle of iterating
        # and getting strange bugs....
        marker_copy = @markers.dup
        marker_copy.each do |m|

          marker_genotype_string = "#{m.symbol} genotype: "
          total_genotypes = 0
          total_null_genotypes = 0

          all_genotypes_null = true
          @genotypes[m].each do |g|

            # skip genotypes for strains no in our list
            if !@strain_list.has_key?(g.strain_id.to_s)
              next
            end

            # increase the count of total genotypes for the strains of interest (== strains.size?)
            total_genotypes += 1

            marker_genotype_string << "#{g.genotype_code} - "

            case g.genotype_code
            when 0
              all_genotypes_null = false
            when 1
              all_genotypes_null = false
            when 2
              all_genotypes_null = false
            else
              total_null_genotypes += 1
            end

          end

          marker_genotype_list[m] = marker_genotype_string

          # if all_genotypes_null == true
          if (params[:strainfilter]['exclude'] != "0" && total_null_genotypes.to_f/total_genotypes.to_f > (params[:strainfilter]['exclude'].to_f/100)) || all_genotypes_null
            @genotypes.delete(m)  # remove marker from genotypes hash
            @removed_markers << m # add marker to list of removed markers
            @markers.delete(m)    # delete from main markers hash
          end
        end

      end

      # $LOG.warn("Ended with #{@markers.size} markers found in region #{@chromosome}: #{@start}-#{@stop}")

      #
      # NOw we have all the data for the markers, etc. this is where the output is created
      # and so it would be one place to subdivide a region into chunks by putting a loop
      # around this output section.

      # Should create new marker lists for each chunk and pass these to the create_haploview_genotype_file
      # method
      #

      # Now decide on the output options
      if params[:output] == nil || params[:output]['options'] == "phased_haplotype"
        @image_src = draw_haplotype_image(@markers, @strains, @genotypes, false)
      elsif params[:output]['options'] == "haploview_basic"
        # Run Haploview to create files
        controller = HaploviewController.new

        # check to see if the region selected is larger than one chunk

        # chunks = ((stop-@start)/params[:haploview]['chunksize']).to_i

        # figure out number of chunks and the start/stop for each chunk
        # then go through markers, moving markers into marker hashes for each chunk
        # then pass each chunk's marker set into the create_haploview_genotype_file method
        # along with the chunk number

        # collect the file path data in an array or similar to pass along to the view for
        # display/links, etc.

        # somewhere here we will need to also process teh TAGS and TEST file to get the overview
        # data for the whole region as well as just the individual chunks.
        # perhaps need to create some objects to hold the data in a more convenient form??

        # have to deal with the asynch nature of haploview - takes a while to run, how to wait
        # for this to happen while still giving some real time feedback to user
        # and then collating results when all is done. Could run the overall analysis as a separate
        # action after the fact - pass in the results directory and allow user to decide if they
        # want to run the overall stats on the various files in the chunk subdirectories. 

        snps_per_chunk = params[:haploview]['snp_chunksize'].to_i || 100
        chunk_number = 1
        chunk_markers = []
        @files = []
        @chunk_info_list = []
        tmp_dir_name = Time.now.to_i
        tmp_file_name = ""
        while !@markers.empty?

          chunk_markers = @markers.slice!(0..snps_per_chunk)
          tmp_file_name = controller.create_haploview_genotype_file(chunk_markers, @strains, @genotypes, tmp_dir_name, chunk_number, params[:haploview])
          chunk_info = {
            "file_name"  => tmp_file_name,
            "snp_count" => chunk_markers.size,
            "start" => chunk_markers[0].map_positions[0].start.to_i,
            "end" => chunk_markers[chunk_markers.size-1].map_positions[0].start.to_i
          }

          @files << tmp_file_name
          @chunk_info_list << chunk_info
          chunk_number += 1
          chunk_markers = []
        end

        @haploview_params = params[:haploview]
        render :action => "haploview_results"
      elsif params[:output]['options'] == "haploview_advanced"
        # Run Haploview to create files
        controller = HaploviewController.new
        @file_path = controller.create_haploview_genotype_file(@markers, @strains, @genotypes, 'chunk_1', params[:haploview])
        @haploview_params = params[:haploview]
        render :action => "haploview_results"
      end


    else
      redirect_to :action => "select_region"
    end

  end

  def create_hmp_file(markers, strains, genotypes)

  end

  def get_marker_list_as_file(markers)
  
    @text_output = "Symbol\tchromosome\tposition\tallele\tsequence\n"

    send_data compress(@text_output),
              :content_type => "application/x-gzip",
              :filename => @list.name.gsub(' ','_') + ".txt.gz"
  end

  def compress(text)
    gz = Zlib::GzipWriter.new(out = StringIO.new)
    gz.write(text)
    gz.close
    return out.string
  end
  
  def get_highres_gbrowse
    
    marker = Marker.find(params[:id])
    
    results_html = "- We were unable to find data for this marker -"
    highres_dna_plus_minus = 32
    lowres_dna_plus_minus = 500
    
    if marker != nil
      begin
        gbrowse_img_url1 = "http://mcnally.hmgc.mcw.edu/gb/gbrowse_img/rgd_904/?name=Chr#{marker.map_positions[0].chromosome_label}%3A#{marker.map_positions[0].start.to_i-highres_dna_plus_minus}..#{marker.map_positions[0].start.to_i+highres_dna_plus_minus};width=400;type=RGD_curated_genes+DNA;options=RGD_curated_genes+3+RGD_SSLP+3+DNA+3;add=Chr#{marker.map_positions[0].chromosome_label}+%22SNP%22+#{marker.symbol}+#{marker.map_positions[0].start.to_i}..#{marker.map_positions[0].start.to_i}"
        gbrowse_img_url2 = "http://mcnally.hmgc.mcw.edu/gb/gbrowse_img/rgd_904/?name=Chr#{marker.map_positions[0].chromosome_label}%3A#{marker.map_positions[0].start.to_i-lowres_dna_plus_minus}..#{marker.map_positions[0].start.to_i+lowres_dna_plus_minus};width=400;type=RGD_curated_genes+RGD_SSLP;options=RGD_curated_genes+3+RGD_SSLP+3+DNA+3;add=Chr#{marker.map_positions[0].chromosome_label}+%22SNP%22+#{marker.symbol}+#{marker.map_positions[0].start.to_i}..#{marker.map_positions[0].start.to_i}"
        
        results_html = "<table><tr><td>High Resolution, #{marker.symbol} +/- #{highres_dna_plus_minus}bp</td><td>Low Resolution, #{marker.symbol} +/- #{lowres_dna_plus_minus}bp</td></tr><tr><td valign=\"top\"><img src=\"#{gbrowse_img_url1}\" width=\"450\" border=\"1\" title=\"Gbrowse image for #{highres_dna_plus_minus}bp +/- #{marker.symbol}\"></td><td valign=\"top\"><img src=\"#{gbrowse_img_url2}\" width=\"450\" border=\"1\" title=\"Gbrowse image for #{lowres_dna_plus_minus}bp +/- around #{marker.symbol}\"></td></tr></table>"
       rescue Timeout::Error
        # Timedout trying to get the gbrowse image
        $LOG.debug("Timed out trying to get GBrowse image")
       results_html = "- Gbrowse Timed out so we were unable to get a map image for this marker -"
      end
    end

    render :partial => "get_highres_gbrowse", :locals => {:html_text => results_html}
  end

  # Provides a method to get the haplotype image via a GET call so that it can
  # be used in mashups in different contexts that in this application. It requires
  # a number of parameters to be passed in via the URL. To create an image for the SNP
  # data on chromosome 2 between 20Mb and 40Mb for the USA Strains, the sample URL would look
  # something like this:
  #
  # http://0.0.0.0:30000/map/get_haplotype_img?chromosome=2&start=20000000&stop=40000000&country=USA
  #
  # * +chromosome+ the chromosome (1-20,X,Y)
  # * +start+ the region start coordinates (base pairs)
  # * +stop+ the region end coordinates (base pairs)
  # * +country+ Optional country designation to select strains from that country

  def get_haplotype_img(map_id)

    map = Map.find(map_id)
    @markers = []
    chromosome = params['chromosome'] || 1
    start = params['start'] || 20000000
    stop = params['end'] || 25000000

    # do the processing to get the data and create the image
    get_region_marker_data(chromosome, start, stop)
    # redirect output to the image file itself, thereby rendering the file
    redirect_to draw_haplotype_image(@markers, @strains, @genotypes, false)

  end

  # Responsible for getting the markers, genotype and strain recors for a given
  # haplotype. This is a generic method called by a number of functions including
  # get_haplotype_img and haplotype_view. Separating the code out allows us to cope
  # with POST requests from the form (haplotype_view) and GET requests for the
  # image itself via get_haplotype_img

  def get_region_marker_data(map_id, chromosome, start, stop)

    map = Map.find(map_id)
    @markers = map.find_on_chr_between_start_and_stop(chromosome.to_i,start.to_i,stop.to_i)

    $LOG.warn("Found marker: #{@markers.size}")

    @start = start
    @stop = stop
    @chromosome = chromosome

    @genotypes = Hash.new
    @markers.each do |m|
      @genotypes[m] = Genotype.find_all_by_genotypable_id(m.id)
    end

  end

  # The main drawing method, it uses RVG to create the haplotype image itself and writes it to
  # a temporary file. The filename for the image is returned to the calling method(s)

  def draw_haplotype_image(markers, strains, genotypes, show_genotype_text)

    RVG::dpi = 72

    box_px = font_size = 12 # Size of a haplotype square
    img_padding = 10  # Extra space on the right side of the image to ensure everything is on.

    hap_start = 300   # Y coords of the start of haplotype squares, strain labels
    hap_x_start = 100 # X coords of the start of the marker data

    chromosome_start = 200  # Y coords of chromsome number
    position_start = 230    # Y coords of basepair number 

    connector_width_px = 30

    image_height_px = hap_x_start + (markers.size * box_px) + img_padding
    image_height_inches = (image_height_px/72).abs

    end_of_haplotype_px = hap_start + (strains.size * box_px) + img_padding
    image_width_px = end_of_haplotype_px + connector_width_px

    if params['gbrowse'] != nil
      # Create the GBrowse image now so we can get the width

      type_list = []
      params['gbrowse'].each do |track,track_is_selected|
        type_list << track if track_is_selected
      end
      
      
      region_width = @stop.to_i - @start.to_i
      if region_width > 3000000
        gene_track_density = 1
      else
        gene_track_density = 3
      end
      
      
      begin
        gbrowse = Magick::Image.from_blob(open("http://mcnally.hmgc.mcw.edu/gb/gbrowse_img/rgd_904/?name=Chr#{@chromosome}%3A#{@start}..#{@stop};width=#{markers.size * box_px};type=#{type_list.join('+')};options=RGD_curated_genes+#{gene_track_density}+RGD_SSLP+3+QTLS+3").read).first
        gbrowse.rotate!(90)

        # length of the gbrowse genome scale in pixels
        # TO-DO Get length of chromosomes so everything scales correctly
        # If the user enters a stop or start that is outside of the chromosome range
        # then the haplotype to gbrowse scale is incorrect.

        gbrowse_scale_length_px = markers.size * (box_px)

        # scale factor, relates bp to pixels
        # hap_to_gbrowse_scale = Float.new
        hap_to_gbrowse_scale = gbrowse_scale_length_px/(@stop.to_f-@start.to_f)
        $LOG.debug("scale factor: #{hap_to_gbrowse_scale}")

        $LOG.debug("GBrowse: rows: #{gbrowse.rows} and cols: #{gbrowse.columns}")
        image_width_px += gbrowse.columns
      rescue Timeout::Error
        # Timedout trying to get the gbrowse image
        # set this to nil so we dont try and draw it again later
        $LOG.debug("Timed out trying to get GBrowse image")
        params['gbrowse'] = nil
      end
    end

    # .viewbox(0,0,image_width_px,image_height_px) 
    rvg = RVG.new(image_width_px, image_height_px ) do |canvas|
      canvas.background_fill = 'white'

      strains.each_with_index do |s,str_i|
        canvas.text(hap_start+(box_px*(str_i+2)), 0) do |str|
          str.tspan(s.symbol).styles(:writing_mode=>'tb',
          :glyph_orientation_vertical=>90,
          :fill=>'black',
          :font_weight=>'bold',
          :font_size=>font_size)
        end
      end


      # Legend in the top left corner
      legend_text = ['Allele 1','Het','Allele 2','No Data Available']
      ['#2768C2','#FFF566','#C43535','white'].each_with_index do |color, index|
        canvas.rect(box_px, box_px, 10, 10+(box_px*(index))).styles(:fill=>color, :stroke=>'darkgrey', :stroke_width=>1)
        canvas.text(10+box_px+10, 10+(box_px*(index+1))) do |legend|
          legend.tspan(legend_text[index]).styles(:font_size=>font_size,
          :font_family=>'helvetica',:font_style => 'italic', :fill=>'darkgrey')
        end
      end

      markers.each_with_index do |m,i|
        canvas.text(10, hap_x_start+(font_size*i)) do |title|
          title.tspan(m.symbol).styles(:font_size=>font_size,
          :font_family=>'helvetica', :fill=>'black')
        end

        # Write chromosome number
        canvas.text(chromosome_start, hap_x_start+(font_size*i)) do |title|
          title.tspan(m.map_positions[0].chromosome_label).styles(:font_size=>font_size,
          :font_family=>'helvetica', :fill=>'black')
        end

        # Write SNP position
        canvas.text(position_start, hap_x_start+(font_size*i)) do |title|
          title.tspan(m.map_positions[0].start.to_i).styles(:font_size=>font_size,
          :font_family=>'helvetica', :fill=>'black')
        end

        # create a RVG Group for the haplotype blocks and reuse?
        j = 1

        # Create a version of the genotype data keyed by strain id
        # so this can be used to ensure genotype order matches the strain order.
        genotypes_by_strain = Hash.new
        genotypes[m].each do |g|
          genotypes_by_strain[g.strain_id] = g
        end
        # $LOG.warn("Genotypes array: #{genotypes_by_strain}")


        strains.each do |s|
          g = genotypes_by_strain[s.id]
          next if g == nil
          if @strain_list.has_key?(g.strain_id.to_s) == false
            next
          end

          canvas.text(hap_start+(box_px*j), hap_x_start+(box_px*i)) do |gen|
            if g != nil

              if show_genotype_text
                gen.tspan(g.genotype_code).styles(:font_size=>font_size, :font_family=>'helvetica', :fill=>'black')
              end

              case g.genotype_code
              when 0
                box_fill = '#2768C2'
              when 1
                box_fill = '#FFF566'
              when 2
                box_fill = '#C43535'
              when 5
                box_fill = 'white' # no result
              when 6
                box_fill = 'white' # not run
              else
                box_fill = 'grey'
              end

              canvas.rect(box_px, box_px, hap_start+(box_px*j), hap_x_start+(box_px*(i-1))).styles(:fill=>box_fill, :stroke=>'darkgrey', :stroke_width=>1)

            else
              gen.tspan('?').styles(:font_size=>font_size,
              :font_family=>'helvetica', :fill=>'black')
            end
          end
          j += 1
        end

        if params['gbrowse'] != nil
          tick_width = 5

          canvas.line(
          hap_start+(box_px*j+1),
          hap_x_start+(box_px*(i-1))+box_px/2,
          hap_start+(box_px*j+1)+connector_width_px,
          hap_x_start+ (m.map_positions[0].start.to_i - @start.to_i)*hap_to_gbrowse_scale - 10
          ).styles(:fill=>'none', :stroke=>'lightgrey', :stroke_width=>1)

          canvas.line(
          hap_start+(box_px*j+1)+connector_width_px,
          hap_x_start+ (m.map_positions[0].start.to_i - @start.to_i)*hap_to_gbrowse_scale - 10,
          hap_start+(box_px*j+1)+connector_width_px+tick_width, hap_x_start+ (m.map_positions[0].start.to_i - @start.to_i)*hap_to_gbrowse_scale - 10
          ).styles(:fill=>'none', :stroke=>'lightgrey', :stroke_width=>1)
        end

      end
    end

    # add the GBrowse image onto the haplotype view
    main_img = rvg.draw
    main_img.composite!(gbrowse,end_of_haplotype_px+img_padding+connector_width_px,hap_x_start-38,MultiplyCompositeOp) if params['gbrowse'] != nil

    #gbrowse.rotate!(90)
    if params[:orientation] != nil
      main_img.rotate!(270)
      $LOG.debug(">> Rotatated main image: #{params[:orientation]}")
    else
      $LOG.debug("Didnt rotate main image: #{params[:orientation]}")
    end

    Dir.chdir("#{RAILS_ROOT}/public/images")
    tmp_file = "snp_tmp_#{rand(100000)}.gif"
    main_img.write("#{tmp_file}")

    return "/images/#{tmp_file}"
  end

  # Action to allow the user to select the various parameters for the haplotype
  # block they wish to create. It collects the data to construct the haplotype view form
  # with the appropriate chromosome, strain, lab and country data from
  # the database and then renders the form itself.

  def select_region

    origin_labs = Strain.find_by_sql("select origin_lab from strains group by origin_lab")
    @lab_menu = []
    origin_labs.each do |lab|
      @lab_menu << lab.origin_lab if (lab.origin_lab != nil && lab.origin_lab != '')
    end

    origin_country = Strain.find_by_sql("select origin from strains group by origin")
    @country_menu = []
    origin_country.each do |country|
      @country_menu << country.origin if (country.origin != nil && country.origin != '')
    end

    chromosomes = MapPosition.find_by_sql("select chromosome_label from map_positions where map_id = 1 group by chromosome_label order by chromosome_number asc")
    @chromosome_menu = []
    chromosomes.each do |chr|
      @chromosome_menu << chr.chromosome_label
    end

    @strains = Strain.find(:all, :conditions => ['taxon_id = ?',10116], :order => "symbol ASC")

  end

  def select_human_region
    chromosomes = MapPosition.find_by_sql("select chromosome_label from map_positions where map_id = 2 group by chromosome_label order by chromosome_number asc")
    @chromosome_menu = []
    chromosomes.each do |chr|
      @chromosome_menu << chr.chromosome_label
    end

    populations = Population.find(:all, :conditions => ['taxon_id = ?',9606], :order => "symbol ASC")
    @population_menu = []
    populations.each do |pop|
      @population_menu << pop.symbol
    end

    @strains = Strain.find(:all, :conditions => ['taxon_id = ?',9606], :order => "symbol ASC")
    @map_id = 2
  end


end
