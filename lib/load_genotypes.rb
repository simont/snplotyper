#! /usr/local/bin/ruby

File.open(ARGV[0],"r") do |file|
  while (line = file.gets)
  
  line.strip
  data = line.split("\t")
  marker_id = data.shift
  
  data.each_with_index do |g, i|
    strain_id = i+1
    print "#{marker_id}\t#{strain_id}\t\t#{g}\n"
    
  end
end
end