#!/usr/bin/ruby

# make_metadata_chadoxml.rb
# usage : ./make_metadata_chadoxml.rb <sourcechado> <destchado>

### HELPER FUNCTIONS ###

# Does this line contain an open tag that we want to remove?
def open_tag?(line)
  case line
    when /<data_feature>/
      "datafeature"
    when  /<feature id=.*>/
      "feature"
    when  /<feature_relationship>/
      "relationship"
    when  /<analysisfeature>/
      "analysisfeature"
    when  /<featureloc>/
      "featureloc"
    when /<featureprop>/
      "featureprop"
    when /<wiggle_data id=.*>/
      "wiggledata"
    else
      false
    end
end

# Does this line contain the closing tag for the currently open tag?
# If the tag is still open, returns the name;
# otherwise, if it closes, false
def tag_remains_open?(line, matching_tag)
  res = case matching_tag
          when "datafeature"
            "datafeature" unless line =~ /<\/data_feature>/
          when "feature"
           "feature" unless line =~ /<\/feature>/
          when "relationship"
            "relationship" unless line =~ /<\/feature_relationship>/
          when "analysisfeature"
            "analysisfeature" unless line =~ /<\/analysisfeature>/
          when "featureloc"
            "featureloc" unless line =~ /<\/featureloc>/
          when "featureprop"
            "featureprop" unless line =~ /<\/featureprop>/
          end
  res = res || false
end


#### MAIN CODE ####

unless ARGV.length == 2 then
  puts "Usage: ./make_metadata_chadoxml.rb <source> <dest>"
  puts "(Wiggle files will be made in the destination directory.)"
  exit
end

# Get input / output files
sourcename = ARGV[0]
destname = ARGV[1]
destdir = File.dirname(destname)
source = File.open(sourcename, "r")

if File.exists? destname then
  puts "Error: destination file #{destbase} already exists at #{destdir}"
  exit
end
dest = File.open(destname, "w")


current_tag = false
current_wiggle_data = false
current_wiggle_name = nil
current_wiggle_file = nil
# Walk through the sourcefile
source.each{|line| 
  if current_tag && (current_tag != "wiggledata") then # If we have an open tag, just look for the corresponding close tag
    # Check if it's still open; sets flag to false if not
    current_tag = tag_remains_open?(line, current_tag)
    next
  elsif current_tag == "wiggledata" then # we're copying out a wiggle file
    if line =~ /<data>/ then
      current_tag = false
      current_wiggle_data = true
      wig_data_basename = "#{current_wiggle_name}.cleaned.wig"
      wig_data_path = File.join(destdir, wig_data_basename)
      
      datacontents = /<data>(.*)/.match(line)
      if datacontents[1] =~ /Too large, see: .*.cleaned.wig/ then # already cleaned.wig
        puts "Already cleaned wiggle #{wig_data_path}"
        dest.puts line
      else # wiggle data in the chado
        if File.exists? wig_data_path then
          puts "Wiggle #{wig_data_path} already exists, skipping!"
        else
          current_wiggle_file = File.open(wig_data_path, "w")
        end
        current_wiggle_file.puts datacontents[1] unless current_wiggle_file.nil?
        data_indent = /(.*<data>)/.match(line)
        dest.puts "#{data_indent[1]}Too large, see: #{wig_data_basename}"
      end
    elsif line =~ /<name>/ then
      match = /<name>(.*)<\/name>/.match(line)
      current_wiggle_name = match[1]
      dest.puts line
    else # It's just random wiggle stuff like 'gridDefault'
      dest.puts line
    end
  elsif current_wiggle_data then
    if line =~ /<\/data>/ then
      # Done copying data! Close the file, clear what needs clearing
      current_wiggle_file.close unless current_wiggle_file.nil?
      current_wiggle_file = nil
      current_wiggle_name = nil
      current_wiggle_data = false
      dest.puts line
    else # copying the wiggle data lines
     current_wiggle_file.puts line unless current_wiggle_file.nil? 
    end
  else # Otherwise, check for new tags and possibly write line
    current_tag = open_tag?(line)
    dest.puts line unless (current_tag && current_tag != "wiggledata") # found nothing, or wiggle data
  end
}


dest.close

# If there is wiggle data in the file,
# it will create a cleaned wiggle file similar to if the wiggle file is too big.
