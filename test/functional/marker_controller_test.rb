require File.dirname(__FILE__) + '/../test_helper'
require 'marker_controller'

# Re-raise errors caught by the controller.
class MarkerController; def rescue_action(e) raise e end; end

class MarkerControllerTest < Test::Unit::TestCase
  def setup
    @controller = MarkerController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
