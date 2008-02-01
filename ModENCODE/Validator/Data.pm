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

  # For any data field with a cvterm of type where there exists a file
  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      # Do we need to check input data? Maybe, but be careful of rescanning input/output data filling the same role
      foreach my $output_datum (@{$applied_protocol->get_input_data()}) {
      }
    }
  }





  return $success;
}
