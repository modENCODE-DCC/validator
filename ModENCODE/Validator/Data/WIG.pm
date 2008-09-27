package ModENCODE::Validator::Data::WIG;
=pod

=head1 NAME

ModENCODE::Validator::Data::WIG - NEARLY THERE - Class for verifying the data format for the 
UCSC wiggle data format referenced in  BIR-TAB data column objects.

=head1 SYNOPSIS

This class is meant to be used to parse WIG files into
L<ModENCODE::Chado::Wiggle_Data> objects when given L<ModENCODE::Chado::Data>
objects with values that are paths to WIG files. L<Data|ModENCODE::Chado::Data>
are passed in using L<add_datum($datum,
$applied_protocol)|ModENCODE::Validator::Data::Data/add_datum($datum,
$applied_protocol)>, and then the paths in the data's values are validated and
parsed as WIG files and loaded in L<Wiggle_Data|ModENCODE::Chado::Wiggle_Data>
objects. L<Wiggle_Data|ModENCODE::Chado::Wiggle_Data> objects are the type used
to store continuous data for the BIR-TAB Chado extension, and are used for
Wiggle format, BED format, and others.

NOT YET FINISHED
This needs to be modified to handle the BED subtype

=cut
use strict;
use Class::Std;
use Carp qw(croak carp);
use base qw(ModENCODE::Validator::Data::Data);
use ModENCODE::Chado::Wiggle_Data;
use ModENCODE::ErrorHandler qw(log_error);

my %cached_wig_files            :ATTR( :default<{}> );

sub validate {
  my ($self) = @_;
  log_error "Validating attached WIG file(s).", "notice", ">";
  my $success = 1;
  my $last_file = "";
  foreach my $datum_hash (@{$self->get_data()}) {
    my $datum_success = 1;
    my $wig_type = "none";
    my $datum = $datum_hash->{'datum'}->clone();

    if (!length($datum->get_value())) {
      log_error "No WIG file for " . $datum->get_heading(), 'warning';
      $datum_success = 1;
      next;
    } elsif (!-r $datum->get_value()) {
      log_error "Cannot find WIG file " . $datum->get_value() . " for column " . $datum->get_heading();
      $datum_success = 0;
      $success = 0;
    } elsif ($cached_wig_files{ident $self}->{$datum->get_value()}) {
      $datum->add_wiggle_data($cached_wig_files{ident $self}->{$datum->get_value()});
    } else {
      open FH, '<', $datum->get_value();
      my $linenum = 0;

      # Build Wiggle object
      my ($filename) = ($datum->get_value() =~ m/([^\/]+)$/);
#      if ($filename eq $last_file) {
#	  log_error "OH BOY... same file again... this is a BUG", 'notice';
#      }
#      $last_file = $filename;
      log_error "validating: $filename", 'notice' , '>';
      my $wiggle = new ModENCODE::Chado::Wiggle_Data({
          'name' => $filename,
        });
      my $wiggle_data = "";
      while (defined(my $line = <FH>)) {
        $linenum++;
        next if $line =~ m/^\s*#/; # Skip comments
        next if $line =~ m/^\s*$/; # Skip blank lines

	# handle the track header - you can have this more than once
	if ($line =~ m/track type\=wiggle_0/) { #header
	    my ($header) = $line;
	    $wiggle_data .= "$header";
	    next;
	}

	# handle the chrom header
	if ($line =~ m/chrom/) { #another header
	    my ($stepType) = $line =~ /^(variableStep|fixedStep)/;
	    my ($chr)      = $line =~ /chrom=(\S+)/;
	    my ($start)    = $line =~ /start=(\d+)/;
	    my ($step)     = $line =~ /step=(\d+)/;
	    my ($span)     = $line =~ /span=(\d+)/;
	    unless (   $chr =~ /^(I|II|III|IV|V|X|MtDNA)$/ #worm
		    || $chr =~ /^([2-3][LR](Het)?|[X4MU]|[XY]Het|Uextra)$/ #fly
		) {
		log_error "WIG file " . $datum->get_value() . " does not seem valid beginning at line $linenum. The chromosome $chr is invalid:\n      $line";
#		die "I do not recognize chromosome $chr!\n";
		$success = 0;
		$datum_success = 0;
		last;
	    }    
     	    if (!(length($chr) && length($stepType))) {
		log_error "WIG file " . $datum->get_value() . " does not seem valid beginning at line $linenum. Perhaps the chromosome or stepType is invalid:\n      $line";
		$success = 0;
		$datum_success = 0;
		last;
	    }
#	    if (($stepType eq "fixedStep") && !(length($start) && length($step))) {
#		log_error "WIG file " . $datum->get_value() . " is declared fixedStep at line $linenum and does not have either a start position or a step interval:\n      $line";	    
#		$success = 0;
#		$datum_success = 0;
#		last;
#	    }
#	    print STDERR "chr $chr span is $span and length is " . length($span);
	    if (!(length($span))) {  #span is optional
		log_error "WIG file " . $datum->get_value() . " does not seem to have a windowsize indicated at line $linenum: \n      $line", 'notice';
	    }
	    $wig_type = $stepType;  #set the current wig type
	    log_error "Data section for chr $chr found at line $linenum", 'notice';	    
	    $wiggle_data .= "$line";
	    next;
	}
	# handle the data, depending on the WIG type 
	if ($wig_type eq "variableStep") {
	    my ($chrom_start, $value) = ($line =~ m/^(\d+)\s+([-+]?\d+\.?\d*(?:[Ee][-+]?\d+)?)\s*$/); #  714 1.26307949016887
	    if (!(length($chrom_start) && length($value))) {
		log_error "WIG file " . $datum->get_value() . " is declared variableStep and is not properly formatted at line $linenum:\n      $line";	    		
		$success = 0;
		$datum_success = 0;
		last;
	    } elsif ($chrom_start == 0) {
		log_error "WIG file " . $datum->get_value() . " does not seem valid beginning at line $linenum:\n\>      $line.  You have a start coordinate of zero, which may indicate your data are zero-based.  WIG files must be 1-based.\nOnly the first instance is reported.";
		$success = 0;
		$datum_success = 0;
		last;
		
	    } else { 
		$wiggle_data .= "$chrom_start $value\n";
	    }
	} else {
	    if ($wig_type eq "fixedStep") { 
		my ($value) = ($line =~ m/^([-+]?\d+\.?\d*(?:[Ee][-+]?\d+)?)\s*$/); # 1.26307949016887
		if (!(length($value))) {
		    log_error "WIG file " . $datum->get_value() . " is declared fixedStep and is not properly formatted at line $linenum:\n      $line";	    
		    $success = 0;
		    $datum_success = 0;
		    last;
		} else { 
		    $wiggle_data .= "$value\n";
		}
	    }
	}
      }
      close FH;
      $wiggle->set_data($wiggle_data);
      $datum->add_wiggle_data($wiggle) if ($datum_success);
      $cached_wig_files{ident $self}->{$datum->get_value()} = $wiggle;
      log_error "Done: $filename", 'notice' , '<';
    }
    $datum_hash->{'is_valid'} = $datum_success;
    $datum_hash->{'merged_datum'} = $datum;
  }
  log_error "Done.", "notice", "<";
  return $success;
}

sub merge {
  my ($self, $datum, $applied_protocol) = @_;

  return $self->get_datum($datum, $applied_protocol)->{'merged_datum'};
}

1;
