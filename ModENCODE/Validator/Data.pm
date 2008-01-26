package ModENCODE::Validator::Data;
use strict;
use Class::Std;
use Carp qw(croak carp);

sub validate {
  my ($self, $experiment) = @_;
  $experiment = $experiment->clone();
  my $success = 1;

  # TODO
  # For any field that is a "* File" 
  # For any field with a DBxref's DB description of URL_*
  # Convert to a feature. Need some automatically-loaded handlers here



  return $success;
}
