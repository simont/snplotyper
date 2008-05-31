class MarkerController < ApplicationController

  def index
  end

  def list
    @markers = Marker.find(:all)
    @snps = Snp.count
    @microsatellites = Marker.count
  end

  def edit
  end

  def delete
  end
end
