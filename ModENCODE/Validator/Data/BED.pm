package ModENCODE::Validator::Data::BED;
use strict;
use base qw( ModENCODE::Validator::Data::Data );
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::Chado::Wiggle_Data;
use ModENCODE::ErrorHandler qw(log_error);

sub validate {
  my ($self) = @_;
  my $success = 1;
  foreach my $datum_hash (@{$self->get_data()}) {
    my $datum_success = 1;
    my $datum = $datum_hash->{'datum'}->clone();
    if (!length($datum->get_value())) {
      log_error "No BED file for " . $datum->get_heading(), 'warning';
      $datum_success = 1;
    } elsif (!-r $datum->get_value()) {
      log_error "Cannot find BED file " . $datum->get_value() . " for column " . $datum->get_heading();
      $datum_success = 0;
      $success = 0;
    } else {
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
          log_error "BED file " . $datum->get_value() . " does not seem valid beginning at line $linenum:\n      $line";
          $success = 0;
          $datum_success = 0;
          last;
        } else {
          $wiggle_data .= "$chr $start $end $value\n";
        }
      }
      close FH;
      $wiggle->set_data($wiggle_data);
      $datum->add_wiggle_data($wiggle) if ($datum_success);
    }
    $datum_hash->{'is_valid'} = $datum_success;
    $datum_hash->{'merged_datum'} = $datum;
  }
  return $success;
}

sub merge {
  my ($self, $datum, $applied_protocol) = @_;

  return $self->get_datum($datum, $applied_protocol)->{'merged_datum'};
}

1;
