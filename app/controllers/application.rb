# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
  
  require 'logger'
  $LOG = Logger.new($stderr)
  
  GBROWSE_URL = "http://rgd.mcw.edu/gb"
  
  CHR_NUMBERS = {
    '1' => 1,
    '2' => 2,
    '3' => 3,
    '4' => 4,
    '5' => 5,
    '6' => 6,
    '7' => 7,
    '8' => 8,
    '9' => 9,
    '10' => 10,
    '11' => 11,
    '12' => 12,
    '13' => 13,
    '14' => 14,
    '15' => 15,
    '16' => 16,
    '17' => 17,
    '18' => 18,
    '19' => 19,
    '20' => 20,
    '21' => 21,
    '22' => 22,
    'X' => 23,
    'Y' => 24
  }
  
  
end