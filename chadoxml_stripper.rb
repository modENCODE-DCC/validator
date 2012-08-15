class ChadoxmlStripper

  attr_reader :ready

  def initialize(source, dest, command_object = nil)
    @command_object = command_object
    @ready = true 

    unless File.exists? source then
      cmd_puts " Error: Can't find source file #{source}!"
      @ready = false
    end
    
    if File.exists? dest then
      cmd_puts "Error: destination file #{dest} already exists!"
      @ready = false
    end
  
    @sourcepath = source
    @destpath = dest
  end

  # Puts text or sends it to the command-object's stderr, as appropriate
  # For use with the ModEncode rails submission pipeline.
  def cmd_puts text
    if @command_object.nil? then
      puts text
    else
      @command_object.stderr = "" if @command_object.stderr.nil?
      @command_object.stderr += "#{text}\n"
      @command_object.save
    end
  end

  # Copies the chadoxml file at in_path to out_path, stripping out features.
  # Does NOT strip out wiggle data.
  # NOTE if the files at @sourcepath and @destpath have changed since init, random
  # crap could happen. This would be nice to protect against, sometime.
  def strip_features()
    cmd_puts "Stripping features from chadoxml file..."

    # Open the files
    source = File.open(@sourcepath, "r")
    dest = File.open(@destpath, "w")

    current_tag = false # are we currently discarding lines?

    # Iterate through the sourcefile, writing to dest unless it's a feature we don't want
    source.each{|line|
      if current_tag then
        current_tag = tag_still_open?(line, current_tag)
      else
        current_tag = opens_new_tag?(line)
        dest.puts line unless current_tag
      end
    }
    
    source.close
    dest.close
    cmd_puts "Done!"
  end


  # Returns false if the line does not represent the
  # end of the XML tag; otherwise, returns its name.
  def tag_still_open?(line, tag)
    res = case tag
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
    res = res || false # this makes failed result 'false' instead of 'nil'.
  end


  # Returns false if the line does not represent the
  # start of a targeted XML tag; otherwise, returns
  # the name of the tag
  def opens_new_tag?(line)
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
      else
        false
    end 
  end

  # Gets the count of wiggle_datas that are NOT external files.
  def embedded_wiggle_count(filepath)
    total_wigs = ( `grep -c "<wiggle_data id=" #{filepath}` ).to_i
    cleaned_wigs = ( `grep -c "<heading>Cleaned WIG File</heading>" #{filepath}` ).to_i
    total_wigs - cleaned_wigs
  end

end

  # If it's being run as a script, set it up
  if __FILE__ == $0 then
    @verbose = ARGV.include? "-v" 
    @debug = ARGV.include? "-d"
    ARGV.reject!{|i| i == "-v" }
    ARGV.reject!{|i| i == "-d" }

    unless ARGV.length == 2 then
      puts "Usage: ./chadoxml_stripper.rb [-v] [-d] <source> <dest>"
      puts "(Wiggle files will be made in the destination directory.)"
      exit
    end
    source = ARGV[0]
    dest = ARGV[1]
    if embedded_wiggle_count(source) > 0 then
      puts "ERROR: #{File.basename(source)} contains embedded wiggle files! This script" +
           " can only process chadoxml files without embedded wiggles."
      exit
    end
    # Looks ok. Let's make a new ChadoxmlStripper and run that crap.
    cxmlstripper = ChadoxmlStripper.new(source, dest)
    cxmlstripper.strip_features
  end
