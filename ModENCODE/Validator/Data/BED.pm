package ModENCODE::Validator::Data::BED;
use strict;
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::Chado::Wiggle_Data;
use ModENCODE::ErrorHandler qw(log_error);

sub validate {
  my ($self, $datum) = @_;
  $datum = $datum->clone();
  my $success = 1;
  if (!length($datum->get_value())) {
    log_error "No BED file for " . $datum->get_heading(), 'warning';
  }
  if (!-r $datum->get_value()) {
    log_error "Cannot find BED file " . $datum->get_value() . " for column " . $datum->get_heading();
    $success = 0;
  } else {
    open FH, '<', $datum->get_value();
    my $linenum = 0;
    while (defined(my $line = <FH>)) {
      $linenum++;
      next if $line =~ m/^\s*#/; # Skip comments
      next if $line =~ m/^\s*$/; # Skip blank lines
      my ($chr, $start, $end, $value) = ($line =~ m/^\s*(\S+)\s+(\d+)\s+(\d+)\s+([-+]?\d+\.?\d*(?:[Ee][-+]?\d+)?)\s*$/);
      if (!(length($chr) && length($start) && length($end) && length($value))) {
        log_error "BED file " . $datum->get_value() . " does not seem valid beginning at line $linenum:\n      $line";
        $success = 0;
        last;
      }
    }
    close FH;
  }
  return $success;
}

sub merge {
  my ($self, $datum) = @_;
  $datum = $datum->clone();
  if (!length($datum->get_value())) {
    return $datum;
  }
  if (!-r $datum->get_value()) {
    croak "    Cannot find BED file " . $datum->get_value() . " for column " . $datum->get_heading();
  }
  open FH, '<', $datum->get_value();
  my $linenum = 0;
  # Build Wiggle object
  my ($filename) = ($datum->get_value() =~ m/([^\/]+)$/);
  my $wiggle = new ModENCODE::Chado::Wiggle_Data({
      'name' => $filename,
    });

  my $wiggle_data = "";
  while (defined(my $line = <FH>)) {
    $linenum++;
    next if $line =~ m/^\s*#/; # Skip comments
    next if $line =~ m/^\s*$/; # Skip blank lines
    my ($chr, $start, $end, $value) = ($line =~ m/^\s*(\S+)\s+(\d+)\s+(\d+)\s+([-+]?\d+\.?\d*(?:[Ee][-+]?\d+)?)\s*$/);
    if (!(length($chr) && length($start) && length($end) && length($value))) {
      croak "    BED file " . $datum->get_value() . " does not seem valid beginning at line $linenum:\n      $line";
    }
    $wiggle_data .= "$chr $start $end $value\n";
  }
  $wiggle->set_data($wiggle_data);

  close FH;
  $datum->set_wiggle_data($wiggle);

  return $datum;
}

1;
