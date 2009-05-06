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
my %seen_data           :ATTR( :default<{}> );       

sub validate {
  my ($self) = @_;
  my $success = 1;

  log_error "Validating attached WIG file(s).", "notice", ">";

  while (my $ap_datum = $self->next_datum) {
    my ($applied_protocol, $direction, $datum) = @$ap_datum;
    next if $seen_data{$datum->get_id}++; # Don't re-update the same datum
    my $datum_obj = $datum->get_object;

    my $wig_type = "none";

    if (!length($datum_obj->get_value())) {
      log_error "No WIG file for " . $datum->get_heading(), 'warning';
      next;
    } elsif (!-r $datum_obj->get_value()) {
      log_error "Cannot find WIG file " . $datum_obj->get_value() . " for column " . $datum_obj->get_heading() . " [" . $datum_obj->get_name . "].", "error";
      $success = 0;
      next;
    } elsif ($cached_wig_files{ident $self}->{$datum_obj->get_value()}++) {
      log_error "Referring to the same WIG file (" . $datum_obj->get_value . ") in two different data columns!", "error";
      $success = 0;
      next;
    }

    # Read the file
    open FH, '<', $datum_obj->get_value() or croak "Couldn't open file " . $datum_obj->get_value . " for reading; fatal error";
    my $linenum = 0;

    # Build Wiggle object
    my ($filename) = ($datum_obj->get_value() =~ m/([^\/]+)$/);
    my $wiggle = new ModENCODE::Chado::Wiggle_Data({
        'name' => $filename,
        'datum' => $datum,
      });
    $datum->get_object->add_wiggle_data($wiggle);

    log_error "Validating WIG file: $filename", 'notice' ;
    my $wiggle_data = "";
    while (defined(my $line = <FH>)) {
      $linenum++;
      next if $line =~ m/^\s*#/; # Skip comments
      next if $line =~ m/^\s*$/; # Skip blank lines

      # handle the track header - you can have this more than once
      if ($line =~ m/track.+type\=wiggle_0/) { #header
        my ($header) = $line;
        $wiggle_data .= "$header";
        next;
      }

      # handle the chrom header
      if ($line =~ m/chrom/) {

        $line =~ s/chrom=chr/chrom=/; # Strip preceding "chr" for compatibility with UCSC

        my ($stepType) = $line =~ /^(variableStep|fixedStep)/;
        my ($chr)      = $line =~ /chrom=(\S+)/;
        my ($start)    = $line =~ /start=(\d+)/;
        my ($step)     = $line =~ /step=(\d+)/;
        my ($span)     = $line =~ /span=(\d+)/;


        unless (   $chr =~ /^(I|II|III|IV|V|X|MtDNA)$/ #worm
          || $chr =~ /^([2-3][LR](Het)?|[X4MU]|[XY]Het|Uextra)$/ #fly
        ) {
          log_error "WIG file " . $datum_obj->get_value() . " does not seem valid beginning at line $linenum. The chromosome $chr is invalid:\n      $line";
          $success = 0;
          last;
        }
        if (!(length($chr) && length($stepType))) {
          log_error "WIG file " . $datum_obj->get_value() . " does not seem valid beginning at line $linenum. Perhaps the chromosome or stepType is invalid:\n      $line";
          $success = 0;
          last;
        }
        if (!(length($span))) {
          # Span is optional
          log_error "WIG file " . $datum_obj->get_value() . " does not seem to have a windowsize (span) indicated at line $linenum: \n      $line", 'notice';
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
          log_error "WIG file " . $datum_obj->get_value() . " is declared variableStep and is not properly formatted at line $linenum:\n      $line";	    		
          $success = 0;
          last;
        } elsif ($chrom_start == 0) {
          log_error "WIG file " . $datum_obj->get_value() . " does not seem valid beginning at line $linenum:\n\>      $line.  You have a start coordinate of zero, which may indicate your data are zero-based.  WIG files must be 1-based.\nOnly the first instance is reported.";
          $success = 0;
          last;

        } else { 
          $wiggle_data .= "$chrom_start $value\n";
        }
      } elsif ($wig_type eq "fixedStep") {
        my ($value) = ($line =~ m/^([-+]?\d+\.?\d*(?:[Ee][-+]?\d+)?)\s*$/); # 1.26307949016887
        if (!(length($value))) {
          log_error "WIG file " . $datum_obj->get_value() . " is declared fixedStep and is not properly formatted at line $linenum:\n      $line";	    
          $success = 0;
          last;
        } else { 
          $wiggle_data .= "$value\n";
        }
      } else {
        # Assume BED
        my ($chr, $start, $end, $value) = ($line =~ m/^\s*(\S+)\s+(\d+)\s+(\d+)\s+([-+]?\d+\.?\d*(?:[Ee][-+]?\d+)?)\s*$/);

        $chr =~ s/^chr//; # Strip preceding "chr" for compatibility with UCSC

        unless (   $chr =~ /^(I|II|III|IV|V|X|MtDNA)$/ #worm
          || $chr =~ /^([2-3][LR](Het)?|[X4MU]|[XY]Het|Uextra)$/ #fly
        ) {
          log_error "WIG file " . $datum_obj->get_value() . " does not seem valid beginning at line $linenum. The chromosome $chr is invalid:\n      $line";
          $success = 0;
          last;
        }    
        if (!(length($chr) && length($start) && length($end) && length($value))) {
          log_error "WIG file " . $datum_obj->get_value() . " is assumed to be BED format and is not properly formatted at line $linenum:\n      $line";	    		
          $success = 0;
          last;
        } else {
          $wiggle_data .= "$chr $start $end $value\n";
        }
      }
    }
    close FH;

    $wiggle->get_object->set_data($wiggle_data);
  }

  log_error "Done.", "notice", "<";
  return $success;
}

1;
