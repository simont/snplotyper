require File.dirname(__FILE__) + '/../test_helper'
require 'haploview_controller'

# Re-raise errors caught by the controller.
class HaploviewController; def rescue_action(e) raise e end; end

class HaploviewControllerTest < Test::Unit::TestCase
  def setup
    @controller = HaploviewController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    
    @data_path = "#{RAILS_ROOT}/tmp"
    @analysis_name = "test123"
  end

  # Replace this with your real tests.
  def test_file_structure_creation
   assert @controller.create_analysis_directories(@data_path,@analysis_name)
   assert File.exists?("#{@data_path}/data/#{@analysis_name}")
   assert @controller.create_analysis_chunk_directory("#{@data_path}/data/#{@analysis_name}","chunk1")
   assert File.exists?("#{@data_path}/data/#{@analysis_name}/chunk1")
  end
  
  
  # remove the files after each test so we have a clean slate
  def teardown
    FileUtils.rm_r "#{@data_path}/data"
  end
end
