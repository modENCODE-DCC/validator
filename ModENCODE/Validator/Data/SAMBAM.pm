package ModENCODE::Validator::Data::SAMBAM;
=pod

=head1 NAME

ModENCODE::Validator::Data::SAMBAM - Class for verifying the data format for the 
SAM and/or alignment format referenced in  BIR-TAB data column objects.

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
Wiggle format, BED format, and in this case, SAM ro BAM.



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
  my $sam_bam_tools_path = ModENCODE::Config::get_root_dir() . "sam_bam_verify/";
  my $fasta_path = ModENCODE::Config::get_root_dir() . "fasta/";

  log_error "Validating attached SAM/BAM file(s).", "notice", ">";
  my $read_count = 0;
  my $read_count_for_expmt = 0;
  while (my $ap_datum = $self->next_datum) {
    my ($applied_protocol, $direction, $datum) = @$ap_datum;
    next if $seen_data{$datum->get_id}++; # Don't re-update the same datum
    my $datum_obj = $datum->get_object;

    if (!length($datum_obj->get_value())) {
      log_error "No SAM/BAM file for " . $datum_obj->get_heading(), 'warning';
      next;
    } elsif (!-r $datum_obj->get_value()) {
      log_error "Cannot find SAM/BAM file " . $datum_obj->get_value() . " for column " . $datum_obj->get_heading() . " [" . $datum_obj->get_name . "].", "error";
      $success = 0;
      next;
    } elsif ($cached_sam_files{ident $self}->{$datum_obj->get_value()}++) {
      log_error "Referring to the same SAM/BAM file (" . $datum_obj->get_value . ") in two different data columns!", "error";
      $success = 0;
      next;
    }

    my $linenum = 0;

    # Build Wiggle object
    my ($filename) = ($datum_obj->get_value() =~ m/([^\/]+)$/);

    my $shell_safe_filename = $datum_obj->get_value();
    if ($shell_safe_filename =~ /^\./ || $shell_safe_filename =~ /[ ;&><|()\[\]]/) {
	log_error "$shell_safe_filename contains dangerous characters ( ;&<>|()[] ); please rename!", "error";
	return 0;
    }

 
    log_error "Validating SAM/BAM file: $filename", 'notice', ">" ;
    my @modencode_header = ();

    

    my $cmd_flags = "";
    if ($filename =~ /BAM/i) {
	$cmd_flags = "-H";
    }
    else {
	#assuming that its a SAM or sam.gz file
	$cmd_flags = "-SH";
    }
    #this command will fetch the header out of the sam/bam file.
    my $cmd = "$samtools_path/samtools view $cmd_flags $filename";
    
    my $output = `$cmd`;
    my @file_header = split(/\n/,$output);
    if (@file_header == 0) {
	#no header
	log_error "You do not have a header in your file $filename.  We don't know what organism this is for", "error";
	$success = 0;
	last;
    } else {
        my @filtered_header;
	($success, @filtered_header) = verify_header(@file_header);
	if (!$success) { #the header doesn't match our genome-build definitions.  fail.	    
	    last;
	} else {
          my ($fh) = grep { $_ =~ /Drosophila|Caenorhabditis/ } @filtered_header;
          ($fa_organism) = ($fh =~ m/((Drosophila|Caenorhabditis) \w*)/);  
          log_error "Header verified.  Organism set to $fa_organism.", "notice";
	}

    }
 
    return 0 if ($success == 0);
       
    my $bam_file = "";

#    if ($filename =~ /BAM/i) {
#	#check the BAM file for chrs
#	$output = `$samtools_path/samtools view $filename | head -n 1`;
#	if ($output =~ /chr/) {
#	    log_error "There are chrs in the chrom names.  FAIL, for now.", "error", ">";
#	    $success = 0;
#	    return 0;
#	}
#	$bam_file = $filename;
 #   } else {
#	#check the SAM file for chrs 
#	log_error "Done", "notice", "<";
#
#	#now validate the SAM file, by converting to BAM
#	log_error "Converting SAM->BAM format using $fa_organism fasta on server", "notice", ">";	
#
#	my $fa_file = "";
#	#will need to change these if we allow different versions of builds
#	#TODO: move these file name paths into the validator.ini file
#	$fa_file = $fasta_path . "elegans.WS190.dna.fa.fai" if ($fa_organism eq "Caenorhabditis elegans");
#	$fa_file =  $fasta_path . "dmel.r5.9.dna.fa.fai" if ($fa_organism eq "Drosophila melanogaster");
#	$fa_file =  $fasta_path . "dpse.r2.6.dna.fa.fai" if ($fa_organism eq "Drosophila pseudoobscura pseudoobscura");
#	$fa_file =  $fasta_path . "dsim.r1.3.dna.fa.fai" if ($fa_organism eq "Drosophila simulans");
#	$fa_file =  $fasta_path . "dsec.r1.3.dna.fa.fai" if ($fa_organism eq "Drosophila sechellia");
#	$fa_file =  $fasta_path . "dper.r1.3.dna.fa.fai" if ($fa_organism eq "Drosophila persimilis");
#	$fa_file =  $fasta_path . "dmoj.r1.3.dna.fa.fai" if ($fa_organism eq "Drosophila mojavensis");
    
#	log_error "Testing SAM->BAM conversion", "notice", ">";
#	unless ($fa_file) {
#	    log_error "Couldn't figure out what FASTA file to use for \"$fa_organism\"!", "error";
#	    return 0;
#	}

#	$bam_file = "$shell_safe_filename.bam";
#	#TODO: use new function from EO to make bam file w/o chr prefixes
#	my $cmd = "$samtools_path/samtools import $fa_file $shell_safe_filename $bam_file 2>&1";
#	my $output = `$cmd`;
#	if ($? || $output =~ /fail to open file for reading/) {
#	    log_error "You have an error in your SAM file \"$shell_safe_filename\"", "error";
#	    for my $err_line (split(/\n/, $output)) { log_error $err_line, "error"; }
#	    unlink("$bam_file") || die ("Cannot delete temp file $bam_file");
#	    return 0;
#	}
#	log_error "Done.  SAM file converted to BAM.", "notice", "<";
#
 #   }


#    #get the read counts in the file
#    $cmd = "$samtools_path/samtools flagstat $bam_file";
#    log_error "Fetching statistics for the reads in the file $filename", "notice", ">";
#    $output = `$cmd`;
#    my @file_stats = split(/\n/,$output);
#    for my $line (@file_stats) {
#	log_error $line, "notice";
#	if ($read_count == 0) {
#	    if ($line =~ m/\d+ mapped \(.*\)$/) {
#		($read_count) = ($line =~ m/(\d+) mapped/);
#	    }
#	} 
#    }
#    log_error "Done", "notice", "<";

    log_error "Processing file $filename.", "notice", ">";
    $bam_file = $filename . ".bam";
    my $cmd = "$sam_bam_tools_path/sam_bam_verify $filename $bam_file";
    my $output = `$cmd 2>&1`;
    foreach (split("\n", $output)) {
      log_error "[sam_bam_verify] $_", "notice";
    }
    my ($read_count) = ($output =~ m/Unique mapped reads: (\d+)/);

    if ($read_count == 0) {
	#throw an error if there's no reads in the file
	log_error "There are no reads in your file", "error";
	return 0;
    } else {
	log_error "Found $read_count mapped reads in your file", "notice";
    }


    #test the bam sorting and indexing.
    log_error "Testing BAM file integrity", "notice", ">";

    my $bam_sorted_file_prefix = "$bam_file.sorted";
    my $bam_sorted_file = "$bam_sorted_file_prefix.bam";
    log_error "Sorting BAM file into $bam_sorted_file", "notice", ">";
    $output = `$samtools_path/samtools sort $bam_file $bam_sorted_file_prefix 2>&1`;
    if ($? || $output =~ /fail to open file for reading/ || !(-e $bam_sorted_file)) {
	log_error "You have an error in your file \"$bam_file\"", "error";
	for my $err_line (split(/\n/, $output)) { log_error $err_line, "error"; }
	unlink("$bam_file") || die ("Cannot delete temp file $bam_file");
	unlink("$bam_sorted_file") || die ("Cannot delete temp file $bam_sorted_file");
	return 0;
    }
    log_error "Done.", "notice", "<";
    
    my $bam_index_file = "$bam_sorted_file.bai";
    log_error "Indexing BAM file into $bam_index_file", "notice", ">";
    $output = `$samtools_path/samtools index $bam_sorted_file $bam_index_file 2>&1`;
    if ($? || $output =~ /fail to open file for reading/ || !(-e $bam_index_file)) {
	log_error "You have an error in your SAM file \"$bam_sorted_file\"", "error";
	for my $err_line (split(/\n/, $output)) { log_error $err_line, "error"; }
	unlink("$bam_file") || die ("Cannot delete temp file $bam_file");
	unlink("$bam_sorted_file") || die ("Cannot delete temp file $bam_sorted_file");
	unlink("$bam_index_file") || die ("Cannot delete temp file $bam_index_file");
	return 0;
    }
    log_error "Done.", "notice", "<";    

    $datum->get_object->add_attribute(new ModENCODE::Chado::DatumAttribute({
	'datum' => $datum,
	'heading' => 'BAM File',
	'value' => "$bam_file",
	'type' => new ModENCODE::Chado::CVTerm({ 'name' => 'string', 'cv' => new ModENCODE::Chado::CV({ 'name' => 'xsd' }) })
									   })
	);
    $datum->get_object->add_attribute(new ModENCODE::Chado::DatumAttribute({
	'datum' => $datum,
	'heading' => 'Sorted BAM File',
	'value' => "$bam_sorted_file",
	'type' => new ModENCODE::Chado::CVTerm({ 'name' => 'string', 'cv' => new ModENCODE::Chado::CV({ 'name' => 'xsd' }) })
									   })
	);
    $datum->get_object->add_attribute(new ModENCODE::Chado::DatumAttribute({
	'datum' => $datum,
	'heading' => 'Sorted BAM File Index',
	'value' => "$bam_index_file",
	'type' => new ModENCODE::Chado::CVTerm({ 'name' => 'string', 'cv' => new ModENCODE::Chado::CV({ 'name' => 'xsd' }) })
									   })
	);
    log_error "BAM file verified.", "notice", "<";

    #add a mapped read count attribute for just this file
    $datum->get_object->add_attribute(new ModENCODE::Chado::DatumAttribute({
	'datum' => $datum,
	'heading' => 'Mapped read count',
	'value' => $read_count,
	'type' => new ModENCODE::Chado::CVTerm({ 'name' => 'int', 'cv' => new ModENCODE::Chado::CV({ 'name' => 'xsd' }) })
									   })
	);
    $read_count_for_expmt += $read_count;
  }

  #sum up all the read counts, and add a total mapped read count as an experiment prop
  my $title = 'Total Mapped Read Count';
  my $experiment = $self->get_experiment();
  my ($exp_read_count) = new ModENCODE::Chado::ExperimentProp({
      'name' => $title,
      'value' => $read_count_for_expmt,
      'experiment' => $experiment,
      'type' => new ModENCODE::Chado::CVTerm({ 'name' => 'mapped_read_count', 'cv' => new ModENCODE::Chado::CV({ 'name' => 'modencode' }) }),							   });
  $experiment->add_property($exp_read_count);

  log_error "Found $read_count_for_expmt total mapped reads for this experiment", "notice";
  log_error "Done.", "notice", "<";
  return $success;
}

sub verify_header {
    my @header = @_;

    # Get genome builds

    my $config = ModENCODE::Config::get_genome_builds();
    my @build_config_strings = keys(%$config);
    my $build_config = {};
    my %organisms;
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
      $organisms{$config->{$build_config_string}->{'organism'}} = 1;
      #push (@organisms, $config->{$build_config_string}->{'organism'});
    }
    my $success = 1;
    my $header_linenum = 0;
    my @modencode_header;
    # Need to verify the SAM header against known genome info
    foreach my $line (@header) {
	if ($line =~ m/^\s*@/) { #header
	    $header_linenum++;
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
		($organism) = ($header =~ m/\tSP:([^\t]+)\t?/);
		($build) = ($header =~ m/\tAS:([^\t]+)\t?/);
		($chrom) = ($header =~ m/\tSN:(\S+)\t?/);
		($chrom_end) = ($header =~ m/\tLN:(\d+)\t?/);
		if ($chrom =~ m/chr/) {
		    log_error "Stripping off \"chr\" from chromosome name $chrom in header.", "notice";
		    $header =~ s/SN:chr/SN:/;
		    $chrom =~ s/chr//;
		}
		($source,$build) = ($build =~ m/(\S+) (\S+)/);
                next if $source =~ /SPIKE/;
                next if $source =~ /PLASMID/;
    # SPECIAL CASE for D. mel : if it's a specific build within r5, strip the build id.
    # The genome-builds file uses only the assembly number.
    if ( ($source eq "FlyBase") && ($build =~ /^r5\..+$/) ) {
        log_error "Setting FlyBase build $build to r5 for consistency.", "notice" ;
        $build = "r5" ; 
    }
		if (!exists $build_config->{$source}) {
		    log_error "You have specified an invalid source of \"$source\" at line $header_linenum in the header","error" ;
		    $success = 0;
		}
		
		if (!exists $build_config->{$source}->{$build}) {
		    log_error "You have specified an invalid build of \"$build\" for source \"$source\" at line $header_linenum in the header", "error";
		    $success = 0;
		}
		
		if (!exists $build_config->{$source}->{$build}->{$chrom}) {
		    log_error "You have specified an invalid chromosome " . $chrom . " for $organism in \"$source\" at line $header_linenum in the header", "error";
		    $success = 0;
		}
		if ($build_config->{$source}->{$build}->{$chrom}->{'end'} != $chrom_end) {
		    log_error "You have specified a bad length for \"$source $build $chrom\" at line $header_linenum in the header (Expected " . $build_config->{$source}->{$build}->{$chrom}->{'end'} . ", got $chrom_end.  Please verify the build or the length. ", "error";
		    $success = 0;
		}

                if ($organism eq "" && $build ne "") {
                  log_error "No SP:organism specified in your SAM header. Attempting to detect it from the build.", "warning";
                  ($organism) = map { $_->{'organism'} } values(%{$build_config->{$source}->{$build}});
                  if ($organism) {
                    log_error "Set organism to $organism based on build.", "warning";
                    $header .= "\tSP:$organism";
                  }
                }
                if ($organism eq "") {
                  log_error "No SP:organism specified in your SAM header. And couldn't detect it from the build.", "error";
                  $success = 0;
                  last;
                }
		if (!exists($organisms{$organism})) {
		    log_error "You have specified an invalid species of \"$organism\" at line $header_linenum in the header", "error";
		    $success = 0;
		}
		
		
		if ((($organism ne "") && ($build ne "") && ($chrom ne "") && ($chrom_end ne "")) || ($success==0)) {
		    #if each of these are filled in and no errors, add to the header array
		    push(@modencode_header, $header);
		} else {
		    log_error "You have a non-standard sequence header line at line $header_linenum", "error";
		    log_error ">  $header", "notice";
		    $success = 0;
		}
	    }
	}
    }
    return $success, @modencode_header;
}

1;
