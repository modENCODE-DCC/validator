package ModENCODE::Validator::Data::Result_File;
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
    my $datum = $datum_hash->{'datum'}->clone();
    if (length($datum->get_value())) {
      next if ($datum->get_value() =~ m/(http|ftp):\/\//);
      if (!-r $datum->get_value()) {
        log_error "Can't find Result File [" . $datum->get_name() . "]=" . $datum->get_value() . ".";
        $success = 0;
      }
    }
  }

  return $success;
}

sub merge {
  my ($self, $datum, $applied_protocol) = @_;
  return $datum;
}

1;
