require File.dirname(__FILE__) + '/../test_helper'
require 'admin_controller'

# Re-raise errors caught by the controller.
class AdminController; def rescue_action(e) raise e end; end

class AdminController2Test < Test::Unit::TestCase
  
  # fixtures :maps
  
  def setup
    @controller = AdminController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    
    @existing_strain_count = Strain.count

    # test files
    @str_file = 'str_test.txt'# test file

  end
  
  def test_str_test_files
    # Check we can see the test file and read it
    assert (File.file? "#{RAILS_ROOT}/test/mocks/#{@str_file}")
    assert (File.readable? "#{RAILS_ROOT}/test/mocks/#{@str_file}")
  end

  # Test parsing the STR data
  def test_parse_str_data
    file_array = []
    File.open("#{RAILS_ROOT}/test/mocks/#{@str_file}","r") do |file|
      while (f = file.gets)
        file_array << f
      end
    end
    # 9 lines in the file
    assert_equal 9, file_array.size
    assert_equal 0, Strain.find(:all).size
    @controller.process_str_file(file_array)
    
    assert_equal 2, Trait.find(:all).size
    first_strain = Strain.find(:first)
    assert_equal 'ACI/N Jacob', first_strain.symbol
    last_strain = Strain.find_by_symbol('48495_4')
    assert_equal '48495_4', last_strain.symbol
    first_measurement = TraitMeasurement.find(:first)
    assert_equal 102, first_measurement.value
    last_strain_measurement = TraitMeasurement.find_by_strain_id(last_strain.id)
    assert_equal 83, last_strain_measurement.value
    
    assert_equal 3, Snp.find(:all).size
    a_snp = Snp.find_by_symbol('gko-118g10_rp2_b1_118')
    assert_equal 229399235, a_snp.map_positions[0].start
    first_genotype = a_snp.genotypes.find_by_strain_id(first_strain.id)
    assert_equal 'NN', first_genotype.genotype_allele
    
    second_strain =  Strain.find_by_symbol('BN/NHsdMcwi Jacob (MDC-03-05)')
    second_genotype = a_snp.genotypes.find_by_strain_id(second_strain.id)
    assert_equal 'GG', second_genotype.genotype_allele
    
    assert_equal 3, Microsatellite.find(:all).size
    sslp = Microsatellite.find_by_symbol('D1Rat324')
    assert_equal 223, sslp.reference_sslp_size
    sslp_aci = sslp.genotypes.find_by_strain_id(Strain.find_by_symbol('ACI/N Jacob').id)
    assert_equal 236, sslp_aci.size
    
    sslp_het = sslp.genotypes.find_by_strain_id(Strain.find_by_symbol('41770_3').id)
    assert sslp_het.is_het
    assert_equal 221, Strain.find(:all).size
  end
end