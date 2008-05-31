class AnalysisController < ApplicationController
  require 'rubygems'
  require 'rsruby'
  require 'rvg/rvg'
  require 'open-uri'
  include Magick

  # verify :method => :post, :only => [ :edit, :visualize ],
  # :add_flash => { "warning" => "Redirect due to post problems" },
  # :redirect_to => { :action => :new }

  # The new method creates the initial form to create a new analysis
  def new
    @include_snps = false
    @include_microsatellites = false
    # puts "Session: #{cookies[SNPLOTYPER_COOKIE_NAME]}"
    @analysis = Analysis.new({'session_id' => cookies[SNPLOTYPER_COOKIE_NAME]})
    @analysis.save
    # @analysis.session_id = cookies['snplotyper_dev']
    session[:analysis] = @analysis
    # end
    @analysis_history = @analysis_history = get_history(@analysis.session_id, @analysis.id)

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

    @traits = Trait.find(:all)

    @strains = Strain.find(:all, :conditions => ['taxon_id = ?',10116], :order => "symbol ASC")
    @strains_by_first_letter = Hash.new
    @strains_by_first_letter_checkbox_status = Hash.new
    
    @strains.each do |str|
      current_letter = str.symbol[0,1].upcase
      if @strains_by_first_letter.has_key?(current_letter)
        @strains_by_first_letter[current_letter] += 1
      else
        @strains_by_first_letter[current_letter] = 1
      end
       @strains_by_first_letter_checkbox_status[current_letter] = false
    end

  end

  # def my_clone
  #     @prev_analysis = Analysis.find(params['the_id'])
  #     @analysis = @prev_analysis.clone
  #     @prev_analysis.strains.each do |str|
  #       @analysis.strains << str.clone
  #     end
  #     
  #     @analysis.save
  #     session[:analysis] = @analysis
  #   end

  def get_history(session_id, current_analysis_id)
    if session_id != nil
      analyses = Analysis.find_all_by_session_id(session_id, :order => "updated_at DESC", :limit => 11)
      filtered_analyses = [] # will hold the final set of valid analyses
      
      analyses.each do |a|
        
        if a.id == current_analysis_id
          # puts "skipped #{a.id} because its the current analysis"
          next # dont want to delete the current analysis as it may legitimately have no data in it at this point
        end
        
        if a.chromosome == nil || a.start == nil || a.end == nil || a.strains.empty?
          Analysis.destroy(a.id) # remove from the database table
          # puts "Skipped #{a.id} because of incomplete analysis params"
          next
        end
        filtered_analyses << a
        
      end
      if filtered_analyses.size > 0
        return filtered_analyses
      else
        return []
      end
    else
      return []
    end
  end

  def edit

    begin
      if !params['the_id']
        flash[:warning] = "I was unable to find that analysis, please create a new one. [Missing ID]"
        redirect_to :action => new
        return  
      end

      if params['clone']
        @prev_analysis = Analysis.find(params['the_id'])
        @analysis = @prev_analysis.clone
        @prev_analysis.selected_strains.each do |str|
          @analysis.selected_strains << str.clone
        end
        @analysis.save
        session[:analysis] = @analysis
      else
        @analysis = Analysis.find(params['the_id'])
      end
    rescue
      flash[:warning] = "I had problems finding that analysis, please create a new one."
      redirect_to :controller => "analysis", :action => new
      return
    end
    # end
    # @analysis = Analysis.find(session[:analysis].id)
    
    # default to include both types of marker.
    @include_microsatellites = true
    @include_snps = true
    
    @analysis_history = get_history(@analysis.session_id, @analysis.id)

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

    @traits = Trait.find(:all)
    @strains = Strain.find(:all, :conditions => ['taxon_id = ?',10116], :order => "symbol ASC")
    
    # if the region parameters are complete, check the number of SNPs in
    # this region so the user gets some quick feedback
    @snp_count = 0
    @microsat_count = 0
    if @analysis.region_complete?
      selected_map = 1; #params[:analysis]['map_id'] || 1
      map = Map.find(selected_map)
      marker_hash = map.find_on_chr_between_start_and_stop(@analysis.chromosome.to_i,@analysis.start,@analysis.end)
      @snp_count = marker_hash.include?("Snp") ? marker_hash["Snp"].size : 0
      @microsat_count = marker_hash.include?("Microsatellite") ? marker_hash["Microsatellite"].size : 0
    end
    
    # create a hash of the first letters of each of the selected strains so we can make sure
    # those tabs are open when the list of strains are rendered
    @selected_strain_letters = Hash.new
    @analysis.strains.each do |s|
      if @selected_strain_letters.has_key?(s.symbol[0,1])
        @selected_strain_letters[s.symbol[0,1]] += 1
      else
        @selected_strain_letters[s.symbol[0,1]] = 1
      end
    end
    
    @strains_by_first_letter = Hash.new
    @strains_by_first_letter_checkbox_status = Hash.new
    
    @strains.each do |str|
      current_letter = str.symbol[0,1].upcase
      if @strains_by_first_letter.has_key?(current_letter)
        @strains_by_first_letter[current_letter] += 1
      else
        @strains_by_first_letter[current_letter] = 1
      end
      
      # If all the strains for a given letter are checked, this will end in true, otherwise false
      if @selected_strain_letters[current_letter] == @strains_by_first_letter[current_letter]
        @strains_by_first_letter_checkbox_status[current_letter.to_s] = true
      else
        @strains_by_first_letter_checkbox_status[current_letter.to_s] = false
      end
    end
    
  end

  def parse_list_parameters

    @analysis = session[:analysis]
    if params.has_key?(:output) && params['output']['primary_strain'] != nil
      @primary_strain_id = params['output']['primary_strain']
      @analysis.primary_strain_id = params['output']['primary_strain'].to_i
      # $LOG.warn("Primary strain: #{@primary_strain_id} ")
    end


    # used to indicate if all the appropriate values have been filled in
    # is set to false if anything is missing, this can then be used to
    # to activate/inactivate the submit button on the form to ensure
    # people submit correct information to the software.
    @form_complete = true
    @region_complete = true

    @chromosome = @analysis.chromosome # params[:analysis]['chromosome']
    @start = @analysis.start #.gsub(/,/,'').to_i # params[:analysis]['start'].gsub(/,/,'').to_i
    @stop = @analysis.end #.gsub(/,/,'').to_i # params[:analysis]['end'].gsub(/,/,'').to_i

    # Compile the list of strains using the various strain selectors
    # and filters (Country and Lab) available on the form
    @strains = []
    @strain_list = Hash.new
    @include_snps = false
    @include_microsatellites = false
    
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

    if params.has_key?(:markerfilter)
      @include_snps = params[:markerfilter]['include_snps'] || false
      @include_microsatellites = params[:markerfilter]['include_sslps'] || false
    end

    # @removed_markers = []   # array to hold any markers removed because all data was missing

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

    if params.has_key?(:analysis) && params[:analysis]['chromosome'] != nil
      if valid_params?('chromosome', params[:analysis]['chromosome'])
        @analysis.update_attribute('chromosome' , params[:analysis]['chromosome'])
      end
    else
      @analysis.update_attribute('chromosome' ,nil)
    end
    

    if params.has_key?(:analysis) && params[:analysis]['start'] != nil
      if valid_params?("start", params[:analysis]['start'])
        @analysis.update_attribute('start', params[:analysis]['start'])
      end
    else
      @analysis.update_attribute('start',nil)
    end

    if params.has_key?(:analysis) && params[:analysis]['end'] != nil
      if valid_params?("end", params[:analysis]['end'])
        @analysis.update_attribute('end', params[:analysis]['end'])
      end
    else
      @analysis.update_attribute('end',nil)
    end


    # if the region parameters are complete, check the number of SNPs in
    # this region so the user gets some quick feedback
    @snp_count = 0
    @microsat_count = 0
    if @analysis.region_complete?
      selected_map = 1; #params[:analysis]['map_id'] || 1
      map = Map.find(selected_map)
      marker_hash = map.find_on_chr_between_start_and_stop(@analysis.chromosome.to_i,@analysis.start,@analysis.end)
      @snp_count = marker_hash.include?("Snp") ? marker_hash["Snp"].size : 0
      @microsat_count = marker_hash.include?("Microsatellite") ? marker_hash["Microsatellite"].size : 0
    end

    

    if !valid_params?("strains", params[:strain])
      # There are no strains selected on the form, therefore
      # remove any remaining strains from the database associated with this analysis
      SelectedStrain.delete_all("analysis_id = #{@analysis.id}")
      @form_complete = false
    else
      # clear out the old records
      @analysis.strains.each do |str|
        # Check previous selected strains and remove any that have been unchecked on the form
        if @strains.index(str) == nil
          SelectedStrain.delete_all("analysis_id = #{@analysis.id} and strain_id = #{str.id}")
        else
          $LOG.warn("updating strain_group for #{str.id}: " + params["#{str.id}_group"])
          if params["#{str.id}_group"]
            ss = @analysis.selected_strains.find_by_strain_id(str.id)
            ss.update_attribute('analysis_group', params["#{str.id}_group"].to_i)
          end
        end
      end
      # SelectedStrain.delete_all("analysis_id = #{@analysis.id}")
      #Go through all the selected strains and add any new ones
      @strains.each do |str|
        if @analysis.strains.index(str) == nil
          @analysis.strains << str
          if params["#{str.id}_group"]
            ss = @analysis.selected_strains.find_by_strain_id(str.id)
            ss.update_attribute('analysis_group', params["#{str.id}_group"].to_i)
          end
        end
      end
    end
    @analysis.save!
  end

  def list_parameters2

    @session_id = cookies[SNPLOTYPER_COOKIE_NAME]

    $LOG.warn(params)
    parse_list_parameters

    # render :partial  => "list_parameters"

    # add in RJS to update the primary_strain_id select menu here
    render :update do |page|
      # page['output[primary_strain]'].replace_html :partial => 'primary_strain_select_item'
      page['main_parameters'].replace_html :partial => 'list_parameters'
    end

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
      if value !~ /[0-9,]/
        is_valid = false
      end
    when "end"
      if value.empty?
        is_valid = false
      end
      if value !~ /[0-9,]/
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

  def process_selection_params(analysis)


    @chromosome = analysis.chromosome # params[:analysis]['chromosome']
    @start = analysis.start #.gsub(/,/,'').to_i # params[:analysis]['start'].gsub(/,/,'').to_i
    @stop = analysis.end #.gsub(/,/,'').to_i # params[:analysis]['end'].gsub(/,/,'').to_i

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

    if params.has_key?('output') && params['output']['primary_strain'] != nil && params['output']['primary_strain'] != 'no_primary' && @strains.include?(Strain.find(params['output']['primary_strain']))
      @primary_strain_id = params['output']['primary_strain']
      $LOG.warn("Processing Primary strain: #{@primary_strain_id} ")
    else
      @primary_strain_id = nil
    end

  end

  # Method to sort the list of strains for the form
  # From Rails Recipies, page 26-27
  def sort
    @analysis = Analysis.find(params[:id])
    $LOG.warn("strain list: #{params['strain_list']}")
    @analysis.selected_strains.each do |strain|
      $LOG.warn("Checking selected strain #{strain.id} #{strain.position}:")
      strain.position = params['strain_list'].index("record_#{strain.id.to_s}") + 1
      strain.save
    end
    render :nothing => true
  end

  # delete_old_analysis is called asynchronously to remove an old analysis record
  # from the analysis table

  def delete_old_analysis

    old_analysis = Analysis.find(params[:id])
    # if old_analysis.session_id != cookies['snplotyper_dev']
    #       flash[:error] = 'You are not authorized to delete this analysis.'
    #       redirect_to :controller => 'analysis', :action => 'new'
    #     end

    Analysis.find(params[:id]).destroy
    # flash[:notice] = 'List was successfully deleted.'
    @analysis = session[:analysis]
    @analysis_history = get_history(cookies[SNPLOTYPER_COOKIE_NAME], @analysis.id)
    
    @display_setting = 'block'
    render :partial  => "analysis_history" # , :locals => { :name => "david" }

  end


  ##########
  ##########

  # Action to display the standard haplotype report page, redirects to the select_region
  # action if the request is not a POST

  def visualize

    if request.post?
      if !params['the_id']
        flash[:warning] = "I was unable to find that analysis, please create a new one"
        redirect_to :action => new
        return
      end

      # @analysis = Analysis.find(params['the_id'])
      @analysis = session[:analysis]
      @analysis.save!
      # $LOG.warn("Analysis #{@analysis.chromosome} and strains: #{@analysis.strains}")

      flash[:error] = ""

      # updated to include regex matching for commas also
      # if params[:region]['start'].empty? || params[:region]['start'] !~ /[1-9,]/
      #         flash[:error] += "You must supply a valid start value!<br>"
      #       end
      # 
      #       if params[:region]['end'].empty? || params[:region]['end'] !~ /[1-9,]/
      #         flash[:error] += "You must supply a valid stop value!<br>"
      #       end
      # 
      #       if params[:region]['chromosome'] == '0' || params[:region]['chromosome'] !~ /[\dXY]/
      #         flash[:error] += "You must supply a valid chromosome value!<br>"
      #       end
      # 
      #       unless params.has_key?(:strain)
      #         flash[:error] += "You must select at least one strain!<br>"
      #       end
      # 
      #       if flash[:error] != ""
      #         redirect_to :action => 'select_region' and return
      #       end

      selected_map = 1 # params[:region]['map_id'] || 1
      @map = Map.find(selected_map)
      @markers = []
      @marker_genotypes = Hash.new

      process_selection_params(@analysis)
      $LOG.warn("Params: with #{params} &  #{params['markerfilter']['include_sslps']}") if DEBUG_FLAG
      # do the processing to get the data
      get_region_marker_data(@map.id, @analysis.chromosome, @analysis.start, @analysis.end, params['markerfilter']['include_sslps'], params['markerfilter']['include_snps'])

      # Filter to remove any markers that have no genotype data across the region

      marker_genotype_list = Hash.new

      # hash keyed by strain, listing genotypes for each marker
      r_strain_genotypes = Hash.new
      @original_number_of_markers_in_region = @markers.size
      $LOG.warn("Started with #{@original_number_of_markers_in_region} markers found on map #{@map.id} in region #{@analysis.chromosome}: #{@analysis.start}-#{@analysis.end}") if DEBUG_FLAG
 
      if params[:strainfilter] != nil
        # Create a duplicate copy of @markers that we can iterate over
        # making changes to the parent copy of @markers as we go.
        # previously was deleting keys from Hash in the middle of iterating
        # and getting strange bugs....
        marker_copy = @markers.dup
        polymorphic_markers = Hash.new
        marker_copy.each do |m|

          # Default to true
          polymorphic_markers[m] = true
          marker_genotype_string = "#{m.symbol} genotype: "
          total_genotypes = 0
          
          # marker null genotype count
          # Default to the same number of genotypes as there are strains - this is the max number
          # of null genotypes there could be
          total_null_genotypes = @strain_list.size 

          all_genotypes_null = true

          # TODO - Put code to detect polymorphic markers in here and create new list of markers with polymorphic flag set
          # To hold the genotypes of the strains in each group
          group_genotypes = {
            "1" => [],
            "2" => [] 
          }
          
          @marker_genotypes[m] = Hash.new
          
          @genotypes[m].each do |g|

            # skip genotypes for strains no in our list
            if !@strain_list.has_key?(g.strain_id.to_s)
              next
            end
            # increase the count of total genotypes for the strains of interest (== strains.size?)
            total_genotypes += 1

            if r_strain_genotypes.has_key?(g.strain_id)
              r_strain_genotypes[g.strain_id] << g.get_numeric_genotype
            else
              # put a non-genotype number at the start so R works properly
              r_strain_genotypes[g.strain_id] = [9,g.get_numeric_genotype]
            end

            # $LOG.warn("Adding new vector: #{g.strain_id} : #{r_strain_genotypes[g.strain_id].join(',')}") if DEBUG_FLAG

            if m.class.to_s == "Snp"
              # # add this genotype code to the group_genotype arrays
              strain_group = @analysis.selected_strains.find_by_strain_id(g.strain_id).analysis_group || 1
              group_genotypes["#{strain_group}"] << g.genotype_code
              # $LOG.warn("Genotype COde: _#{g.genotype_code}_")
              if g.genotype_code
                @marker_genotypes[m][g.strain_id] = g.genotype_allele
              else
                @marker_genotypes[m][g.strain_id] = '-'
              end
              
              
              # $LOG.warn("Genotype COdes: _#{ @marker_genotypes[m][g.strain_id]}_ #{g.strain_id}") if DEBUG_FLAG
              if strain_group == 1
                if group_genotypes["2"].include?(g.genotype_code) || g.genotype_code > 3
                  polymorphic_markers[m] = false
                end
              else
                if group_genotypes["1"].include?(g.genotype_code) || g.genotype_code > 3
                  polymorphic_markers[m] = false
                end
              end

              marker_genotype_string << "#{g.genotype_code} - "

              case g.genotype_code
              when 0,1,2
                all_genotypes_null = false
                total_null_genotypes -= 1
              end
            else

              # # add this genotype code to the group_genotype arrays
              the_strain = @analysis.selected_strains.find_by_strain_id(g.strain_id)
              if the_strain != nil
                strain_group = the_strain.analysis_group || 1
              else
                strain_group = 1
              end
              
              group_genotypes["#{strain_group}"] << g.size
              # $LOG.warn("Genotype COde: _#{g.size}_") if DEBUG_FLAG
              if g.size
                @marker_genotypes[m][g.strain_id] = g.size
              else
                @marker_genotypes[m][g.strain_id] = '-'
              end
              # $LOG.warn("Genotype COdes: _#{ @marker_genotypes[m][g.strain_id]}_") if DEBUG_FLAG
               
              if strain_group == 1
                if group_genotypes["2"].include?(g.size) || g.size == nil
                  polymorphic_markers[m] = false
                end
              else
                if group_genotypes["1"].include?(g.size) || g.size == nil
                  polymorphic_markers[m] = false
                end
              end

              marker_genotype_string << "#{g.size} - "

              $LOG.warn("Genotype: #{g.size}") if DEBUG_FLAG
              case g.size
              when nil, 0
                total_null_genotypes -= 1 
              else
                all_genotypes_null = false
              end

            end

          end
          
          # polymorphic markers only make sense if there is data in both groups
          # therefore set this marker to not polymorphic if either of the groups
          # are empty.
          if group_genotypes["1"].empty? || group_genotypes["2"].empty?
            polymorphic_markers[m] = false
          end
          
          marker_genotype_list[m] = marker_genotype_string

          # We can filter out non-polymorphic markers here if we want to.

          if params[:strainfilter] && params[:strainfilter]['exclude'] != "-1"
            
            $LOG.warn("Checking: #{m.symbol} All null? #{all_genotypes_null} form percentage: #{params[:strainfilter]['exclude']}, total_null: #{total_null_genotypes.to_f}, total_genotypes: #{total_genotypes.to_f}, ratio: #{total_null_genotypes.to_f/total_genotypes.to_f}") if DEBUG_FLAG
            if params[:strainfilter]['exclude'] == "0" || all_genotypes_null || (total_null_genotypes.to_f/total_genotypes.to_f) > (params[:strainfilter]['exclude'].to_f/100)
                $LOG.warn("Dropping #{m.symbol}") if DEBUG_FLAG
                # having identified a marker to remove, we need to back its data out of the existing variables
                @genotypes[m].each do |g|
                  # Skip genotypes that are not in the current selected list
                  if !@strain_list.has_key?(g.strain_id.to_s)
                    next
                  end
                  
                  # Remove this genotype value from the end of each of the r_strain_genotype arrays
                  # We can use pop because it should be the last value added to each of these arrays
                  r_strain_genotypes[g.strain_id].pop
                end
                @genotypes.delete(m)  # remove marker from genotypes hash
                @removed_markers << m # add marker to list of removed markers
                @markers.delete(m)    # delete from main markers hash
             end
           end
        end

      end

      $LOG.warn("Ended with #{@markers.size} markers (#{@removed_markers.size} markers removed) found in region #{@chromosome}: #{@start}-#{@stop}") if DEBUG_FLAG
      # $LOG.warn("Genotypes: #{@marker_genotypes}")
      #
      # NOw we have all the data for the markers, etc. this is where the output is created
      # and so it would be one place to subdivide a region into chunks by putting a loop
      # around this output section.

      # Should create new marker lists for each chunk and pass these to the create_haploview_genotype_file
      # method
      #

      @strain_sorted = @analysis.selected_strains.sort_by {|s| s.position}
      @selected_trait = nil
      
      # If a trait has been selected, sort by that instead
      if params[:traitsort] != nil && params[:traitsort]['trait'] != nil && params[:traitsort]['trait'] != '0'
        @strain_sorted = @analysis.selected_strains.sort_by {|s|  if Strain.find(s.strain_id).trait_measurements.find_by_trait_id(params[:traitsort]['trait']) != nil
          Strain.find(s.strain_id).trait_measurements.find_by_trait_id(params[:traitsort]['trait']).value
          else 
             0
          end
             }

        @selected_trait = params[:traitsort]['trait']
      end
     
     
     # Using R to do heirarchical clustering of the strains based on genotypes and/or sslp size
     # null genotypes are set to -1, otherwise we use the 0,1,2,5,6 for SNPs and then the SSLP allele size
     # for the genotype, pass this over to R and let it do its thing...
     #
     
      if params[:output] != nil && params[:output]['hcluster'] != nil
        
        unclustered_strains = [] # Strains with too little data to be worth clustering
        
        begin
          r_strain_list = Array.new
          r_marker_list = Array.new
          r_genotypes = Array.new
          @analysis.selected_strains.each do |str|
            # Get all the null genotypes (-1) for the strain, remember that there are also other strains which havent been genotyped
            # for this marker and so which wont be counted as null genotypes. We have to add these on to the total number of null genotypes
            null_genotypes = (@markers.size - r_strain_genotypes[str.strain_id].size) + r_strain_genotypes[str.strain_id].find_all {|g| g == -1}.size
            $LOG.warn("Checking #{str.id} null genotypes: #{null_genotypes} total genotypes: #{r_strain_genotypes[str.strain_id].size} marker numbers: #{@markers.size} percentage: #{(null_genotypes.to_f/r_strain_genotypes[str.strain_id].size.to_f)}") if DEBUG_FLAG 
            
            # if there are less than 10% of the maximum number genotypes (number of markers) that are null, then add to the clustering
            if (null_genotypes.to_f/@markers.size.to_f) <= 0.2
              r_strain_list << str.id
              $LOG.warn("Selected strain: #{str.strain_id}") if DEBUG_FLAG
              r_genotypes << r_strain_genotypes[str.strain_id]
            else
              $LOG.warn("Skipping #{str.id} due to too many missing genotypes") if DEBUG_FLAG 
              unclustered_strains << str.id
            end
          end
          @markers.each do |m|
            r_marker_list << m.symbol
          end
      
          # $LOG.warn("Genotypes: #{r_genotypes.flatten.size} Strains: #{r_strain_list.size}, Markers: #{@markers.size} calc: #{r_genotypes.size/@markers.size}")
      
          r_strain_symbol_list = []
          r_strain_list.each do |rstr|
            r_strain_symbol_list << Strain.find(SelectedStrain.find(rstr).strain_id).symbol
          end
      
          rcmd = <<HERE
           m = matrix(c(#{r_genotypes.flatten.join(',')}), #{r_strain_list.size}, #{@markers.size+1}, byrow=TRUE, dimnames=list(c('#{r_strain_list.join("','")}'), c('fake','#{r_marker_list.join("','")}')))
           c <- cor(t(m), method="pearson"); d <- as.dist(1-c); hr <- hclust(d, method = "complete", members=NULL)
           hr$labels[hr$order]
HERE
          friendly_R = <<HERE
           m = matrix(c(#{r_genotypes.flatten.join(',')}), #{r_strain_list.size}, #{@markers.size+1}, byrow=TRUE, dimnames=list(c('#{r_strain_symbol_list.join("','")}'), c('fake','#{r_marker_list.join("','")}')))
           c <- cor(t(m), method="spearman"); d <- as.dist(1-c); hr <- hclust(d, method = "complete", members=NULL)
           hr$labels[hr$order]
HERE
          $LOG.warn("R: #{friendly_R}")
          # $LOG.warn("strains: #{r_strain_list.size}, skipped strains: #{unclustered_strains.size}markers #{@markers.size} r_marker_list: #{r_marker_list.size}")
          $LOG.warn("R: #{rcmd}")
          r = RSRuby.instance
          result = r.eval_R(rcmd)
       
          # add on any strains that were not clustered due to too little data
          # on to the end of the list.
          if !unclustered_strains.empty?
            result << unclustered_strains
            excluded_strain_symbols = []
            unclustered_strains.each do |str|
              excluded_strain_symbols << Strain.find(SelectedStrain.find(str).strain_id).symbol
            end
            flash[:warning] = "<b>Please Note:</b> The following strains were excluded from clustering due to lack of genotype data (>10% of genotypes are missing):<br><b>#{excluded_strain_symbols.join(', ')}</b>.<br>These strains have been added on to the right-hand side of the visual haplotype so you can see their available data."
          end
          # $LOG.warn("Result: #{result.join(',')}")
          @strain_sorted = Array.new
          result.flatten.each do |r_str|
            @strain_sorted << SelectedStrain.find(r_str)
          end
          
        rescue RException
          $LOG.error("RException thrown")
          flash[:error] = "There was an error during Hierarchical Clustering, the Strains are listed in their existing order. This may be caused by one strain having no allele data for the entire region, removing a strain like this from the analysis should allow the clustering to work correctly."
        end
      end

      # Now decide on the output options
      if params[:output] == nil || params[:output]['options'] == "phased_haplotype"
        @image_src = draw_haplotype_image(@markers, @strain_sorted, @genotypes, false, polymorphic_markers,'high', 'gif')
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
      $LOG.warn("Not a POST")
      redirect_to :action => "new"
    end

  end

  # get_marker_list_as_file exports the marker and genotype data for the selected analysis as plain
  # tab-delimited text that can be imported into excel, etc.

  def get_marker_list_as_file

    analysis = Analysis.find(params[:id])
    strain_sorted = analysis.selected_strains.sort_by {|s| s.position}
    @text_output = "symbol\tchromosome\tposition\tallele\tsequence"
    strain_sorted.each do |str|
      strain_record = Strain.find(str.strain_id)
      @text_output << "\t#{strain_record.symbol}"
    end
    @text_output << "\n"
     
    @markers = get_region_marker_data(1, analysis.chromosome, analysis.start, analysis.end)
    
    @markers.each do |m|

      if m.sequence != nil
        m.sequence[40] = "[#{m.target_allele}]"
      else
        m.sequence = ""
      end
      @text_output << "#{m.symbol}\t#{m.map_positions[0].chromosome_label}\t#{m.map_positions[0].start}\t#{m.target_allele}\t#{m.sequence}"
      
      strain_sorted.each do |str|
        genotype = Genotype.find_by_genotypable_id_and_strain_id(m.id,str.strain_id)
        @text_output << "\t"
        if genotype != nil
          @text_output << "#{genotype.get_public_genotype}"
        else
          @text_output << "?"
        end
      end
      @text_output << "\n"
      
    end
    
    send_data @text_output,
    :content_type => "text/plain",
    :filename => "snplotyper_chr#{analysis.chromosome}_#{analysis.start}_to_#{analysis.end}" ".txt"
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
        gbrowse_img_url1 = "#{GBROWSE_URL}/gbrowse_img/rgd_904/?name=Chr#{marker.map_positions[0].chromosome_label}%3A#{marker.map_positions[0].start.to_i-highres_dna_plus_minus}..#{marker.map_positions[0].start.to_i+highres_dna_plus_minus};width=400;type=RGD_curated_genes+DNA;options=RGD_curated_genes+3+RGD_SSLP+3+DNA+3;add=Chr#{marker.map_positions[0].chromosome_label}+%22Marker%22+#{marker.symbol}+#{marker.map_positions[0].start.to_i}..#{marker.map_positions[0].start.to_i}"
        gbrowse_img_url2 = "#{GBROWSE_URL}/gbrowse_img/rgd_904/?name=Chr#{marker.map_positions[0].chromosome_label}%3A#{marker.map_positions[0].start.to_i-lowres_dna_plus_minus}..#{marker.map_positions[0].start.to_i+lowres_dna_plus_minus};width=400;type=RGD_curated_genes+RGD_SSLP;options=RGD_curated_genes+3+RGD_SSLP+3+DNA+3;add=Chr#{marker.map_positions[0].chromosome_label}+%22Marker%22+#{marker.symbol}+#{marker.map_positions[0].start.to_i}..#{marker.map_positions[0].start.to_i}"

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
    redirect_to draw_haplotype_image(@markers, @strains, @genotypes, false, 'high', 'gif')

  end

  # Responsible for getting the markers, genotype and strain recors for a given
  # haplotype. This is a generic method called by a number of functions including
  # get_haplotype_img and haplotype_view. Separating the code out allows us to cope
  # with POST requests from the form (haplotype_view) and GET requests for the
  # image itself via get_haplotype_img

  def get_region_marker_data(map_id, chromosome, start, stop, include_sslps=true, include_snps=true)

    map = Map.find(map_id)
    marker_hash = map.find_on_chr_between_start_and_stop(chromosome.to_i,start.to_i,stop.to_i)
    
    @markers = []
    if marker_hash.include?("Microsatellite") && include_sslps
      @markers << marker_hash["Microsatellite"]
    end
    if marker_hash.include?("Snp") && include_snps
        @markers << marker_hash["Snp"]
    end
    # @markers << marker_hash.include?("Microsatellite") ? marker_hash["Microsatellite"] : []
    # @markers << marker_hash.include?("Snp") ? marker_hash["Snp"] : []
        
    @markers.flatten!
    @markers.sort! {|x,y| x.map_positions[0].start <=> y.map_positions[0].start }
     
     
    # $LOG.warn("Found marker: #{@markers.size}")
    # 
    #    @markers.each {|m| $LOG.warn("Found: #{m.symbol}")}

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

  def draw_haplotype_image(markers, selected_strains, genotypes, show_genotype_text, polymorphic_markers, resolution, format)

    # TODO
    # See if this following section is necessary, does the selected_strains variable already contain
    # the strain objects? If so, not sure why we get them from the database again...
    strains = []
    selected_strains.each do |sel_str|
      strains << Strain.find(sel_str.strain_id)
    end

    # end TODO

    # Show SNP and strain information on image
    show_labels = true

    RVG::dpi = 72

    if resolution == "low"
      show_labels = false
      box_px = font_size = 3 # Size of a haplotype square
    else
      box_px = font_size = 12 # Size of a haplotype square
    end
    
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
        gbrowse = Magick::Image.from_blob(open("#{GBROWSE_URL}/gbrowse_img/rgd_904/?name=Chr#{@chromosome}%3A#{@start}..#{@stop};width=#{markers.size * box_px};type=#{type_list.join('+')};options=RGD_curated_genes+#{gene_track_density}+RGD_SSLP+3+QTLS+3").read).first
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

      if show_labels
        strains.each_with_index do |s,str_i|
          # s = Strain.find(selected_strain.strain_id)
          canvas.text(hap_start+(box_px*(str_i+2))-(box_px/4), box_px) do |str|
            str.tspan(s.symbol).styles(:writing_mode=>'tb',
            :glyph_orientation_vertical=>90,
            :fill=>'black',
            :font_weight=>'bold',
            :font_size=>font_size)
          end

        #TODO Put a circle or other indicator above the strain symbol to represent the group
        box_fill = '#BDA7A7'
        offset = 0
        if selected_strains[str_i].analysis_group == 2
          box_fill = '#AABDA7'
          offset = 3
        end

        canvas.rect(box_px-2, box_px/4, hap_start+(box_px*(str_i+1)), 0+offset).styles(:fill=>box_fill, :stroke=>'darkgrey', :stroke_width=>1)
        end
        # canvas.text(hap_start+(box_px*(str_i+1)), 9) do |str|
        #           str.tspan(selected_strains[str_i].analysis_group).styles(:writing_mode=>'lr',
        #           :glyph_orientation_vertical=>0,
        #           :fill=>'#666',
        #           :font_weight=>'bold',
        #           :font_size=>font_size)
        #         end
      end

      ###############
      #
      # Legend in the top left corner
      #
      ###############
      legend_text = ['Allele 1','Het','Allele 2','No Data Available']
      legend_colors = [GENOTYPE_ALLELE_1_COLOR,GENOTYPE_HET_COLOR,GENOTYPE_ALLELE_2_COLOR,GENOTYPE_NO_DATA_COLOR]

      if @primary_strain_id != 'no_primary' && @primary_strain_id != nil
        primary_strain = Strain.find(@primary_strain_id)
        # Just in case we dont find the primary strain by id
        if primary_strain != nil
          legend_text = [primary_strain.symbol,'Het',"Diff. from #{primary_strain.symbol}",'No data available','No data in Primary']
          legend_colors = [GENOTYPE_ALLELE_1_COLOR,GENOTYPE_HET_COLOR,GENOTYPE_ALLELE_2_COLOR, GENOTYPE_NO_DATA_COLOR, GENOTYPE_UNKNOWN_COLOR]
        end
      end

      legend_colors.each_with_index do |color, index|
        canvas.rect(box_px, box_px, 10, 10+(box_px*(index))).styles(:fill=>color, :stroke=>'darkgrey', :stroke_width=>1)
        canvas.text(10+box_px+10, 10+(box_px*(index+1))) do |legend|
          legend.tspan(legend_text[index]).styles(:font_size=>font_size,
          :font_family=>'helvetica',:font_style => 'italic', :fill=>'darkgrey')
        end
      end

      markers.each_with_index do |m,i|

        if show_labels
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

          # Write The Polymorphism Flag (or image ultimately?) on the left of the marker
          if polymorphic_markers[m]
             canvas.circle(3,position_start+75, hap_x_start-(box_px/2)+(font_size*i) ).styles(:fill=>"#F67EF7", :stroke=>'#763D77', :stroke_width=>1)
          end
        end
        # create a RVG Group for the haplotype blocks and reuse?
        j = 1

        # Create a version of the genotype data keyed by strain id
        # so this can be used to ensure genotype order matches the strain order.
        genotypes_by_strain = Hash.new
        genotypes[m].each do |g|
          genotypes_by_strain[g.strain_id] = g
        end
        

        strains.each_with_index do |s,str_i|
          g = genotypes_by_strain[s.id]
          # next if g == nil
          if g != nil && @strain_list.has_key?(g.strain_id.to_s) == false
            next
          end

          canvas.text(hap_start+(box_px*j), hap_x_start+(box_px*i)) do |gen|
            if g != nil

              if show_genotype_text
                if m.class.to_s == 'Snp'
                  gen.tspan(g.genotype_code).styles(:font_size=>font_size, :font_family=>'helvetica', :fill=>'black')
                else
                  gen.tspan(g.size).styles(:font_size=>9, :font_family=>'helvetica', :fill=>'black')
                end
                
              end

              # If there is a primary strain selected, and its one of our selected strains
              if @primary_strain_id != nil && @primary_strain_id != 'no_primary' && genotypes_by_strain.has_key?(@primary_strain_id.to_i)


                # IF this is the reference strain
                if g.strain_id == @primary_strain_id.to_i

                  if m.class.to_s == 'Snp'
                    case g.genotype_code
                    when 5, 6 # if its no result or no data then color white
                      box_fill = GENOTYPE_NO_DATA_COLOR # no result
                    when 1 # if its a het, still color yellow
                      box_fill = GENOTYPE_HET_COLOR
                    else 
                      box_fill = GENOTYPE_ALLELE_1_COLOR # otherwise color blue
                    end
                  else
                    case g.size
                    when nil
                      box_fill = GENOTYPE_NO_DATA_COLOR # no result
                    else
                      box_fill = GENOTYPE_ALLELE_1_COLOR # otherwise color blue
                    end
                  end


                else
                  # Not the reference strain, color based on reference strain genotype
                  reference_genotype = genotypes_by_strain[@primary_strain_id.to_i]

                  if m.class.to_s == 'Snp'
                    case g.genotype_code
                    when 5, 6 # if no result or no data then color white
                      box_fill = GENOTYPE_NO_DATA_COLOR # no result
                    when 1 # if its a het, still color yellow
                      box_fill = GENOTYPE_HET_COLOR
                    when reference_genotype.genotype_code # if its the same as the genotype of the reference strain, color blue
                      box_fill = GENOTYPE_ALLELE_1_COLOR
                    else 
                      box_fill = GENOTYPE_ALLELE_2_COLOR # otherwise color red
                    end

                    # Grey out non-reference strain data if the reference strain is missing real allele data
                    # case reference_genotype.genotype_code 
                    #                     when 5, 6, 1
                    #                       box_fill = GENOTYPE_UNKNOWN_COLOR
                    #                     end
                  else
                    case g.size
                    when nil
                      box_fill = GENOTYPE_NO_DATA_COLOR # no result
                    when reference_genotype.size
                      box_fill = GENOTYPE_ALLELE_1_COLOR # no result
                    else
                      box_fill = 'red' # otherwise color orange, not the same
                    end

                    case reference_genotype.size 
                    when nil
                      box_fill = GENOTYPE_UNKNOWN_COLOR
                    end
                  end
                end

              else
                # No primary color scheme enabled, colore each based on the standard reference.
                if m.class.to_s == 'Snp'
                  case g.genotype_code
                  when 0
                    box_fill = GENOTYPE_ALLELE_1_COLOR
                  when 1
                    box_fill = GENOTYPE_HET_COLOR
                  when 2
                    box_fill = GENOTYPE_ALLELE_2_COLOR
                  when 5
                    box_fill = GENOTYPE_NO_DATA_COLOR # no result
                  when 6
                    box_fill = GENOTYPE_NO_DATA_COLOR # not run
                  else
                    box_fill = GENOTYPE_UNKNOWN_COLOR
                  end
                  
                else
                  case g.size
                  when nil
                    box_fill = GENOTYPE_NO_DATA_COLOR # no result
                  else
                    
                    if m.reference_sslp_size != nil
                      bp_difference = m.reference_sslp_size - g.size
                      new_color = GENOTYPE_NO_DATA_COLOR # default
                      if bp_difference > 0
                        green_number = 255-(bp_difference*10)
                        box_fill = "#FF#{green_number.to_i.to_s(16)}#{green_number.to_i.to_s(16)}"
                      elsif bp_difference < 0
                        blue_number = 255-(-bp_difference*10)
                        box_fill = "##{blue_number.to_i.to_s(16)}#{blue_number.to_i.to_s(16)}FF"
                      else
                         box_fill = GENOTYPE_ALLELE_1_COLOR
                      end
                    else
                      new_color = (g.size.to_f/300) * 256
                    
                      box_fill = "##{new_color.to_i.to_s(16)}FF#{(256-new_color).to_i.to_s(16)}" # otherwise color blue
                    end
                  end
                end
              end

              canvas.rect(box_px, box_px, hap_start+(box_px*j), hap_x_start+(box_px*(i-1))).styles(:fill=>box_fill, :stroke=>'darkgrey', :stroke_width=>1)

            else
              box_fill = GENOTYPE_NO_DATA_COLOR # no result
              canvas.rect(box_px, box_px, hap_start+(box_px*j), hap_x_start+(box_px*(i-1))).styles(:fill=>box_fill, :stroke=>'darkgrey', :stroke_width=>1)
              #gen.tspan('?').styles(:font_size=>font_size, :font_family=>'helvetica', :fill=>'black')
            end

            # else??
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
    tmp_file = "snp_tmp_#{rand(100000)}.#{format}"
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



  ##########
  ##########


end
