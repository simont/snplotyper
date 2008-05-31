class Panel < ActiveRecord::Base
  
  has_many :panel_markers
  has_many :markers, :through => :panel_markers
  
  validates_presence_of :name
  validates_uniqueness_of :name
  validates_presence_of :manufacturer
  
end
