package ModENCODE::Validator::Data::SAM;
=pod

=head1 NAME

ModENCODE::Validator::Data::SAM - Class for verifying the data format for the 
SAM alignment format referenced in  BIR-TAB data column objects.

=head1 SYNOPSIS

This class is meant to be used to parse SAM files into
L<ModENCODE::Chado::Wiggle_Data> objects when given L<ModENCODE::Chado::Data>
objects with values that are paths to SAM files. L<Data|ModENCODE::Chado::Data>
are passed in using L<add_datum($datum,
$applied_protocol)|ModENCODE::Validator::Data::Data/add_datum($datum,
$applied_protocol)>, and then the paths in the data's values are validated and
parsed as SAM files and loaded in L<Wiggle_Data|ModENCODE::Chado::Wiggle_Data>
objects. L<Wiggle_Data|ModENCODE::Chado::Wiggle_Data> objects are the type used
to store continuous data for the BIR-TAB Chado extension, and are used for
Wiggle format, BED format, and in this case, SAM.

=cut
use strict;
use Class::Std;
use Carp qw(croak carp);
use base qw(ModENCODE::Validator::Data::Data);
use ModENCODE::Chado::Wiggle_Data;
use ModENCODE::ErrorHandler qw(log_error);
use File::Temp qw();
use PerlIO::gzip;

my %cached_sam_files            :ATTR( :default<{}> );
my %seen_data           :ATTR( :default<{}> );       


sub validate {
  my ($self) = @_;
  my $success = 1;
  my $fa_organism = "";
  my $samtools_path = ModENCODE::Config::get_root_dir() . "samtools/";
  my $fasta_path = ModENCODE::Config::get_root_dir() . "fasta/";

  log_error "Validating attached SAM file(s).", "notice", ">";
  my $read_count = 0;
  while (my $ap_datum = $self->next_datum) {
    my ($applied_protocol, $direction, $datum) = @$ap_datum;
    next if $seen_data{$datum->get_id}++; # Don't re-update the same datum
    my $datum_obj = $datum->get_object;

    if (!length($datum_obj->get_value())) {
      log_error "No SAM file for " . $datum->get_heading(), 'warning';
      next;
    } elsif (!-r $datum_obj->get_value()) {
      log_error "Cannot find SAM file " . $datum_obj->get_value() . " for column " . $datum_obj->get_heading() . " [" . $datum_obj->get_name . "].", "error";
      $success = 0;
      next;
    } elsif ($cached_sam_files{ident $self}->{$datum_obj->get_value()}++) {
      log_error "Referring to the same SAM file (" . $datum_obj->get_value . ") in two different data columns!", "error";
      $success = 0;
      next;
    }

    # Read the file
    if ($datum_obj->get_value() =~ /\.(gz|gzip)/) {
	#file is gzipped
	open FH, "<:gzip", $datum_obj->get_value() or croak "Couldn't open file " . $datum_obj->get_value . " for reading; fatal error";
	#my $tmp = "zcat " . $datum_obj->get_value() . " |";
	#open FH, '<', $tmp or croak "Couldn't open file " . $tmp . " for reading; fatal error $!"; 
    } else {
	#file is not zipped
	open FH, '<', $datum_obj->get_value() or croak "Couldn't open file " . $datum_obj->get_value . " for reading; fatal error";
    }

    my $linenum = 0;

    # Build Wiggle object
    my ($filename) = ($datum_obj->get_value() =~ m/([^\/]+)$/);

    # Get genome builds
    # Need to verify the SAM header against known genome info
    my $config = ModENCODE::Config::get_genome_builds();
    my @build_config_strings = keys(%$config);
    my $build_config = {};
    foreach my $build_config_string (@build_config_strings) {
      my (undef, $source, $build) = split(/ +/, $build_config_string);
      $build_config->{$source} = {} unless $build_config->{$source};
      $build_config->{$source}->{$build} = {} unless $build_config->{$source}->{$build};
      my @chromosomes = split(/, */, $config->{$build_config_string}->{'chromosomes'});
      my $type = $config->{$build_config_string}->{'type'};
      foreach my $chr (@chromosomes) {
        $build_config->{$source}->{$build}->{$chr}->{'seq_id'} = $chr;
        $build_config->{$source}->{$build}->{$chr}->{'type'} = $type;
        $build_config->{$source}->{$build}->{$chr}->{'start'} = $config->{$build_config_string}->{$chr . '_start'};
        $build_config->{$source}->{$build}->{$chr}->{'end'} = $config->{$build_config_string}->{$chr . '_end'};
        $build_config->{$source}->{$build}->{$chr}->{'organism'} = $config->{$build_config_string}->{'organism'};
      }
    }
#    my $config = ModENCODE::Config::get_cfg();
#    my @build_config_strings = $config->GroupMembers('genome_build');
#    my $build_config = {};
#    foreach my $build_config_string (@build_config_strings) {
#      my (undef, $source, $build) = split(/ +/, $build_config_string);
#      $build_config->{$source} = {} unless $build_config->{$source};
#      $build_config->{$source}->{$build} = {} unless $build_config->{$source}->{$build};
#      my @chromosomes = split(/, */, $config->val($build_config_string, 'chromosomes'));
#      my $type = $config->val($build_config_string, 'type');
#      foreach my $chr (@chromosomes) {
#        $build_config->{$source}->{$build}->{$chr}->{'seq_id'} = $chr;
#        $build_config->{$source}->{$build}->{$chr}->{'type'} = $type;
#        $build_config->{$source}->{$build}->{$chr}->{'start'} = $config->val($build_config_string, $chr . '_start');
#        $build_config->{$source}->{$build}->{$chr}->{'end'} = $config->val($build_config_string, $chr . '_end');
#        $build_config->{$source}->{$build}->{$chr}->{'organism'} = $config->val($build_config_string, 'organism');
#      }
#    }

    log_error "Validating SAM file: $filename", 'notice' ;
    my @modencode_header = ();

    my $temp_file = new File::Temp(
      DIR => ModENCODE::Config::get_cfg()->val('cache', 'tmpdir'), 
      SUFFIX => ".sam_data"
    );
    
    while (defined(my $line = <FH>)) {
      $linenum++;
      # Skip comments and blank lines
      if ($line =~ m/^\s*#/ || $line =~ m/^\s*$/) {
        print $temp_file $line;
        next;
      }

      # verify that there is a modencode-specific header
      if ($line =~ m/^\s*@/) { #header
	$line =~ s/^\s*//;
        my ($header) = $line;
	my ($organism,$build,$chrom,$chrom_end,$source);
	$organism = $build = $chrom = $chrom_end = $source = "";
	chomp($header);
        $header =~ s/[\r\n]*$//;
	if ($header =~ m/^\@SQ/) {
	    my @s = split("\t", $header);
	    if (@s <=1) {
		log_error "Your header is not tab-delimited", "error";
		$success=0;
		last;
	    }
	    #by rights, i should grab all headers, but i don't care right now
		($organism) = ($header =~ m/\tSP:([^\t]+)\t?/);
		($build) = ($header =~ m/\tAS:([^\t]+)\t?/);
		($chrom) = ($header =~ m/\tSN:(\S+)\t?/);
		($chrom_end) = ($header =~ m/\tLN:(\d+)\t?/);
	    if ($chrom =~ m/chr/) {
		log_error "Stripping off \"chr\" from chromosome name $chrom at header line $linenum", "notice"; 
		$header =~ s/SN:chr/SN:/;
		$chrom =~ s/chr//;
	    }	  
	    if (($organism !~ /Drosophila (melanogaster|pseudoobscura pseudoobscura|simulans|sechellia|persimilis|mojavensis)/) && ($organism ne "Caenorhabditis elegans")) {
		log_error "You have specified an invalid species of \"$organism\" at line $linenum", "error";
		$success = 0;
	    }
	    ($source,$build) = ($build =~ m/(\S+) (\S+)/);

	    if (!exists $build_config->{$source}) {
		log_error "You have specified an invalid source of \"$source\" at line $linenum","error" ;
		$success = 0;
	    }

	    if (!exists $build_config->{$source}->{$build}) {
		log_error "You have specified an invalid build of \"$build\" for source \"$source\" at line $linenum", "error";
		$success = 0;
	    }

	    if (!exists $build_config->{$source}->{$build}->{$chrom}) {
		log_error "You have specified an invalid chromosome " . $chrom . " for $organism in \"$source\" at line $linenum", "error";
		$success = 0;
	    }
	    if ($build_config->{$source}->{$build}->{$chrom}->{'end'} != $chrom_end) {
		log_error "You have specified a bad length for \"$source $build $chrom\" at line $linenum.  Please verify the build or the length. ", "error";
		$success = 0;
	    }


	    if ((($organism ne "") && ($build ne "") && ($chrom ne "") && ($chrom_end ne "")) || ($success==0)) {
		#if each of these are filled in and no errors, add to the header array
		push(@modencode_header, $header);
	    } else {
		log_error "You have a non-standard sequence header line at line $linenum", "error";
		$success = 0;
	    }
	}
        print $temp_file "$header\n";
	last if ($success == 0);
	$fa_organism = $organism;
        next;
      } else {
        $line =~ s/^(([^\t]*\t){2})chr/\1/; # Get rid of "chr" prefix
        print $temp_file $line or die "Cannot write to temp file.  Please tell the DCC to cleanup the temp directory on this machine.";
      }
      $read_count++;
    }
    close FH;

    return 0 if ($success == 0);

    # Copy back over temp file
    if ($datum_obj->get_value() =~ /\.(gz|gzip)/) {
	#orig file is gzipped
	open FH, ">:gzip", $datum_obj->get_value() or croak "Couldn't open file " . $datum_obj->get_value . " for writing; fatal error";
    } else {
	#file is not zipped
	open FH, '>', $datum_obj->get_value() or croak "Couldn't open file " . $datum_obj->get_value . " for writing; fatal error";
    }

    seek($temp_file, 0, 0);
    while (my $tmp_line = <$temp_file>) {
      print FH $tmp_line;
    }
    close FH;
    File::Temp::unlink0($temp_file, $temp_file->filename);


    if ((@modencode_header == 0) || ($success==0)) {
	#throw an error if there's no header at all
	log_error "You do not have the header required by modENCODE.  Please see our documentation at http://wiki.modencode.org/project/index.php/SAM for instructions", "error";
	$success = 0;
    }
    return if ($success==0);
    if ($read_count == 0) {
	#throw an error if there's no reads in the file
	log_error "There are no reads in your file \"$filename\"", "error";
	return 0;
    } else {
	log_error "Processed $read_count reads in SAM file", "notice";
    }

    #now validate it
    
    #try to make the bam file, using import, sort and index functionality in samtools
    log_error "Header verified. Converting SAM->BAM format using $fa_organism fasta on server", "notice", ">";

    my $fa_file = "";
    #will need to change these if we allow different versions of builds
    $fa_file = $fasta_path . "elegans.WS190.dna.fa.fai" if ($fa_organism eq "Caenorhabditis elegans");
    $fa_file =  $fasta_path . "dmel.r5.9.dna.fa.fai" if ($fa_organism eq "Drosophila melanogaster");
    $fa_file =  $fasta_path . "dpse.r2.6.dna.fa.fai" if ($fa_organism eq "Drosophila pseudoobscura pseudoobscura");
    $fa_file =  $fasta_path . "dsim.r1.3.dna.fa.fai" if ($fa_organism eq "Drosophila simulans");
    $fa_file =  $fasta_path . "dsec.r1.3.dna.fa.fai" if ($fa_organism eq "Drosophila sechellia");
    $fa_file =  $fasta_path . "dper.r1.3.dna.fa.fai" if ($fa_organism eq "Drosophila persimilis");
    log_error "Testing SAM->BAM conversion", "notice";
    unless ($fa_file) {
      log_error "Couldn't figure out what FASTA file to use for \"$fa_organism\"!", "error";
      return 0;
    }

    my $shell_safe_filename = $datum_obj->get_value();
    if ($shell_safe_filename =~ /^\./ || $shell_safe_filename =~ /[ ;&><|()\[\]]/) {
      log_error "$shell_safe_filename contains dangerous characters ( ;&<>|()[] ); please rename!", "error";
      return 0;
    }

    my $cmd = "$samtools_path/samtools import $fa_file $shell_safe_filename $shell_safe_filename.bam 2>&1";
    my $output = `$cmd`;
    if ($? || $output =~ /fail to open file for reading/) {
	log_error "You have an error in your SAM file \"$shell_safe_filename\"", "error";
	for my $err_line (split(/\n/, $output)) { log_error $err_line, "error"; }
	unlink("$shell_safe_filename.bam") || die ("Cannot delete temp file $shell_safe_filename.bam");
	return 0;
    }
    log_error "Testing BAM sorting", "notice";
    $output = `$samtools_path/samtools sort $shell_safe_filename.bam $shell_safe_filename.bam.sorted 2>&1`;
    if ($? || $output =~ /fail to open file for reading/) {
	log_error "You have an error in your SAM file \"$shell_safe_filename\"", "error";
	for my $err_line (split(/\n/, $output)) { log_error $err_line, "error"; }
	unlink("$shell_safe_filename.bam") || die ("Cannot delete temp file $shell_safe_filename.bam");
	unlink("$shell_safe_filename.bam.sorted.bam") || die ("Cannot delete temp file $shell_safe_filename.bam.sorted.bam");
	return 0;
    }

    log_error "Testing BAM indexing", "notice";
    $output = `$samtools_path/samtools index $shell_safe_filename.bam.sorted.bam 2>&1`;
    if ($? || $output =~ /fail to open file for reading/) {
	log_error "You have an error in your SAM file \"$shell_safe_filename\"", "error";
	for my $err_line (split(/\n/, $output)) { log_error $err_line, "error"; }
	unlink("$shell_safe_filename.bam") || die ("Cannot delete temp file $shell_safe_filename.bam");
	unlink("$shell_safe_filename.bam.sorted.bam") || die ("Cannot delete temp file $shell_safe_filename.bam.sorted.bam");
	unlink("$shell_safe_filename.bam.sorted.bam.bai") || die ("Cannot delete temp file $shell_safe_filename.bam.sorted.bam.bai");
	return 0;
    }

#    unlink("$shell_safe_filename.bam") || die ("Cannot delete temp file $shell_safe_filename.bam");
#    unlink("$shell_safe_filename.bam.sorted.bam") || die ("Cannot delete temp file $shell_safe_filename.bam.sorted.bam");
#    unlink("$shell_safe_filename.bam.sorted.bam.bai") || die ("Cannot delete temp file $shell_safe_filename.bam.sorted.bam.bai");
    $datum->get_object->add_attribute(new ModENCODE::Chado::DatumAttribute({
          'datum' => $datum,
          'heading' => 'BAM File',
          'value' => "$shell_safe_filename.bam",
          'type' => new ModENCODE::Chado::CVTerm({ 'name' => 'string', 'cv' => new ModENCODE::Chado::CV({ 'name' => 'xsd' }) })
        })
    );
    $datum->get_object->add_attribute(new ModENCODE::Chado::DatumAttribute({
          'datum' => $datum,
          'heading' => 'Sorted BAM File',
          'value' => "$shell_safe_filename.bam.sorted.bam",
          'type' => new ModENCODE::Chado::CVTerm({ 'name' => 'string', 'cv' => new ModENCODE::Chado::CV({ 'name' => 'xsd' }) })
        })
    );
    $datum->get_object->add_attribute(new ModENCODE::Chado::DatumAttribute({
          'datum' => $datum,
          'heading' => 'Sorted BAM File Index',
          'value' => "$shell_safe_filename.bam.sorted.bam.bai",
          'type' => new ModENCODE::Chado::CVTerm({ 'name' => 'string', 'cv' => new ModENCODE::Chado::CV({ 'name' => 'xsd' }) })
        })
    );
    log_error "SAM file verified.", "notice", "<";

  }

  log_error "Done.", "notice", "<";
  return $success;
}


1;
