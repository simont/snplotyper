require File.dirname(__FILE__) + '/../test_helper'
require 'admin_controller'

# Re-raise errors caught by the controller.
class AdminController; def rescue_action(e) raise e end; end

class AdminControllerTest < Test::Unit::TestCase
  
  fixtures :maps
  
  def setup
    @controller = AdminController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    
    @existing_strain_count = Strain.count

    # test files
    @hapmap_filename = 'chr6_hapmap_ceu_snp_genotypes.txt'# test file
    @mdc_filename = 'mdc_test_data.txt'
    @rgd_sslp_filename = "sslp_test_data.txt"

    # Check we can see the test file and read it
    assert (File.file? "#{RAILS_ROOT}/test/mocks/#{@hapmap_filename}")
    assert (File.readable? "#{RAILS_ROOT}/test/mocks/#{@hapmap_filename}")

  end
  
  def test_mdc_test_files
    # Check we can see the test file and read it
    assert (File.file? "#{RAILS_ROOT}/test/mocks/#{@mdc_filename}")
    assert (File.readable? "#{RAILS_ROOT}/test/mocks/#{@mdc_filename}")
  end

  # Test parsing the MDC data
  def test_parse_mdc_snp_data
    column_headings = []
    snp_data = []
    File.open("#{RAILS_ROOT}/test/mocks/#{@mdc_filename}","r") do |file|
      while (f = file.gets)

        next if f =~ /^#/ # ignore lines that start with a hash - comments
        f.strip!  # remove any whitespace, linefeeds, etc.

        # if this line has the column headings, extract and do the next line
        if f =~ /^a1_External_ID/
          column_headings = f.split(/\t/)
          next
        end

        # Split the mdc file based on tabs
        snp_data = f.split(/\t/)

        # load_hapmap_snp_data(column_headings,snp_data)
        break # jump out after first line as we're just testing the parsing
      end # end of file_array.each loop

      # test that we're parsing the headings and the SNP data correctly
      assert_equal 235, snp_data.size
      assert_equal "a2_RGSCv3.4_chr",column_headings[1]
      assert_equal "rat105_009_k11.p1ca_226",snp_data[0]
      assert_equal "2283252",snp_data[2]
      assert_equal '6',snp_data[233] # penultimate entry
      assert_equal '6',snp_data[234] # last entry
      assert_equal nil,snp_data[235] # shouldnt exist
    end
  end
  
  # Test parsing the MDC data
  def test_parse_and_load_mdc_snp_data
    column_headings = []
    snp_data = []
    results = 0
    
    File.open("#{RAILS_ROOT}/test/mocks/#{@mdc_filename}","r") do |file|
      while (f = file.gets)

        next if f =~ /^#/ # ignore lines that start with a hash - comments
        f.strip!  # remove any whitespace, linefeeds, etc.

        # if this line has the column headings, extract and do the next line
        if f =~ /^a1_External_ID/
          column_headings = f.split(/\t/)
          next
        end

        # Split the mdc file based on tabs
        snp_data = f.split(/\t/)

        results += @controller.load_mdc_snp_data(column_headings,snp_data)
        
        assert_equal column_headings.size, snp_data.size
        # break
      end # end of file_array.each loop
      
       # check the results returned match the expected number of snps loaded
        assert 9, results

        # check number of SNPs loaded into the database itself, should be 15
        assert 9, Snp.find(:all).size
        
        # Look for specific SNP
        snp = Snp.find_by_symbol('J500418')
        assert_not_nil snp
        
        strain2 = Strain.find_by_mdc_id('MDC-05-90')
        assert_not_nil strain2
    end
  end


  def test_mdc_genotype_load
    
    test_parse_and_load_mdc_snp_data
    
    run_mdc_content_tests
        
  end


  # Replace this with your real tests.
  def test_parse_hapmap_snp_data
    column_headings = []
    snp_data = []
    File.open("#{RAILS_ROOT}/test/mocks/#{@hapmap_filename}","r") do |file|
      while (f = file.gets)

        next if f =~ /^#/ # ignore lines that start with a hash - comments
        f.strip!  # remove any whitespace, linefeeds, etc.

        # if this line has the column headings, extract and do the next line
        if f =~ /^rs#/
          column_headings = f.split(/\s/)
          next
        end

        # Split the hapmap file based on spaces
        snp_data = f.split(/\s/)

        # load_hapmap_snp_data(column_headings,snp_data)
        break
      end # end of file_array.each loop

      # test that we're parsing the headings and the SNP data correctly
      assert_equal "SNPalleles",column_headings[1]
      assert_equal "rs7754266",snp_data[0]
      assert_equal "ncbi_b35",snp_data[5]
    end
  end

  def test_load_hapmap_snp_data

    column_headings = []
    result = ""
    File.open("#{RAILS_ROOT}/test/mocks/#{@hapmap_filename}","r") do |file|
      while (f = file.gets)

        next if f =~ /^#/ # ignore lines that start with a hash - comments
        f.strip!  # remove any whitespace, linefeeds, etc.

        # if this line has the column headings, extract and do the next line
        if f =~ /^rs#/
          column_headings = f.split(/\s/)
          next
        end

        # Split the hapmap file based on spaces
        snp_data = f.split(/\s/)

        result = @controller.load_hapmap_snp_data(column_headings,snp_data)

      end # end of file_array.each loop
    end# of File.open

    # check the results returned match the expected number of snps loaded
    assert_equal 1, result

    # check number of SNPs loaded into the database itself, should be 15
    assert_equal 15, Snp.find(:all).size

  end# of test_load_hapmap_snp_data
  
  def test_load_rgd_sslp_data
    column_headings = []
    result = ""
    File.open("#{RAILS_ROOT}/test/mocks/#{@rgd_sslp_filename}","r") do |file|
      while (f = file.gets)

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

        result = @controller.load_rgd_sslp_data(column_headings,sslp_data)

        #end # end of while loop
      end # of File.open
    end
    
    assert_equal 1, result
    
    run_sslp_content_tests
   
  end
  
  def test_load_rat_sslp_data_via_webpage
    
    get :load_snps
    assert_response :success
    
    sslp_file = uploaded_file("#{File.expand_path(RAILS_ROOT)}/test/mocks/#{@rgd_sslp_filename}")
    
    post :load_snps, :inputfile => sslp_file, :snp_format => "sslp_allele_data"
    assert_not_nil assigns(:format)
    assert_equal 'sslp_allele_data',assigns(:format)
    # Check that the file array is assigned as expected
    assert_response :success
    assert_not_equal 'Problems loading SNP file...', flash[:error]
    assert_equal 'File processed successfully', flash[:notice]
    
    run_sslp_content_tests
    
  end
  
  def test_hapmap_genotype_load
    
    load_hapmap_data
    
    run_hapmap_content_tests
        
  end
  
  def test_load_hapmap_data_via_webpage
    
    get :load_snps
    assert_response :success
    
    snp_file = uploaded_file("#{File.expand_path(RAILS_ROOT)}/test/mocks/#{@hapmap_filename}")
    
    post :load_snps, :inputfile => snp_file, :snp_format => "hapmap_genotype"
    assert_not_nil assigns(:format)
    assert_equal 'hapmap_genotype',assigns(:format)
    # Check that the file array is assigned as expected
    assert_response :success
    assert_not_equal 'Problems loading SNP file...', flash[:error]
    assert_equal 'File processed successfully', flash[:notice]
    
    run_hapmap_content_tests
    
  end
  
  def test_load_mdc_data_via_webpage
    
    get :load_snps
    assert_response :success
    
    snp_file = uploaded_file("#{File.expand_path(RAILS_ROOT)}/test/mocks/#{@mdc_filename}")
    
    post :load_snps, :inputfile => snp_file, :snp_format => "mdc_data"
    assert_not_nil assigns(:format)
    assert_equal 'mdc_data', assigns(:format)
    # Check that the file array is assigned as expected
    assert_response :success
    assert_not_equal 'Problems loading SNP file...', flash[:error]
    assert_not_equal '', flash[:error]
    assert_equal 'File processed successfully', flash[:notice]
    
    run_mdc_content_tests
    
  end


  private
  
  
  def run_sslp_content_tests
    
   # Confirm they are all Microsatellite markers
    assert_equal 8, Microsatellite.find(:all).size

    # Should all have map positions
    assert_equal 8, MapPosition.find(:all).size

    sslp_d4mit20 = Microsatellite.find_by_rgd_id(10048)
    assert_equal 'D4Mit20', sslp_d4mit20.symbol

    assert_equal 239, Genotype.find(:all).size

    # Should have 48 strain entries now
    # assert_equal 48, Strain.find(:all).size
    aci_strain = Strain.find_by_symbol('ACI')
    assert_equal 239, sslp_d4mit20.genotypes.find_by_strain_id(aci_strain.id).size
    
  end
  
  
  ####
  # Battery of tests that are run to ensure that the MDC test file was loaded correctly
  ####
  
  def run_mdc_content_tests
    assert_not_nil Strain.find(:all)
    # Check strains loaded, start with the first strain in the test file
    strain = Strain.find_by_mdc_id('MDC-03-08')
    assert_not_nil strain
    assert_equal 228, Strain.count
    
    # the last strain in the file
    strain2 = Strain.find_by_mdc_id('MDC-05-90')
    assert_not_nil strain2
    # make sure it loaded the data
    strain2_genotypes = Genotype.find_all_by_strain_id(strain2.id)
    assert_equal 9, strain2_genotypes.size
    
    snp = Snp.find_by_symbol('J500418')
    assert_not_nil snp
    assert_equal 'C/T', snp.target_allele
    
    assert_not_nil Genotype.count
    
    assert_equal (228*9), Genotype.count
    genotypes = Genotype.find_all_by_genotypable_id(snp.id)
    assert_not_nil genotypes
    assert_equal 228, genotypes.size
   
   # Get genotype data for J500418 in strain MDC-03-08
    last_genotype = Genotype.find_by_genotypable_id_and_strain_id(snp.id, strain.id)
    assert_not_nil last_genotype
    assert_equal 'TT',last_genotype.genotype_allele
  end
  
  
  ####
  # Battery of tests that are run to ensure that the hapmap test file was loaded correctly
  ####
  
  def run_hapmap_content_tests
    assert_not_nil Strain.find(:all)
    # Check strains loaded
    strain = Strain.find_by_symbol('NA12892')
    assert_not_nil strain
    assert_equal 90, Strain.count
    
    snp = Snp.find_by_symbol('rs2107722')
    assert_equal 'G/T', snp.target_allele
    
    #chr6 98500
    map_pos = MapPosition.find_all_by_mappable_id(snp.id)
    assert 1, map_pos.size # should only find one location
    assert '6', map_pos[0].chromosome_label
    assert 6, map_pos[0].chromosome_number
    assert 98500, map_pos[0].start
    assert 98500, map_pos[0].end
    
    assert_not_nil Genotype.count
    
    assert_equal (90*15), Genotype.count
    genotypes = Genotype.find_all_by_genotypable_id(snp.id)
    assert_not_nil genotypes
    assert_equal 90, genotypes.size
   
    last_genotype = Genotype.find_by_genotypable_id_and_strain_id(snp.id, strain.id)
    assert_not_nil last_genotype
    assert_equal 'GG',last_genotype.genotype_allele
  end
  
  ##
  # internal method to upload the hapmap file data
  ##
  def load_hapmap_data
    
    column_headings = []
    result = ""
    File.open("#{RAILS_ROOT}/test/mocks/#{@hapmap_filename}","r") do |file|
      while (f = file.gets)

        next if f =~ /^#/ # ignore lines that start with a hash - comments
        f.strip!  # remove any whitespace, linefeeds, etc.

        # if this line has the column headings, extract and do the next line
        if f =~ /^rs#/
          column_headings = f.split(/\s/)
          next
        end

        # Split the hapmap file based on spaces
        snp_data = f.split(/\s/)

        result = @controller.load_hapmap_snp_data(column_headings,snp_data)

      end # end of file_array.each loop
    end# of File.open
    
  end
  
  # From http://manuals.rubyonrails.com/read/chapter/28#page237
  # get us an object that represents an uploaded file so that we can test
  # the file upload as it would be used via the web pages, rather than 
  # just from here.
  def uploaded_file(path, content_type="application/octet-stream", filename=nil)
    filename ||= File.basename(path)
    t = Tempfile.new(filename)
    FileUtils.copy_file(path, t.path)
    (class << t; self; end;).class_eval do
      alias local_path path
      define_method(:original_filename) { filename }
      define_method(:content_type) { content_type }
    end
    return t
  end

end# of class definition
