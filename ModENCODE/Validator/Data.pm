package ModENCODE::Validator::Data;
use strict;
use ModENCODE::Validator::Data::BED;
use ModENCODE::Validator::Data::dbEST_gi;
#use ModENCODE::Validator::Data::NCBITrace;
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::ErrorHandler qw(log_error);

my %validators                  :ATTR( :default<{}> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  # TODO: Figure out how to be more canonical about CV names w/ respect to validation function identifiers
  $validators{$ident}->{'modencode:Browser_Extensible_Data_Format (BED)'} = new ModENCODE::Validator::Data::BED();
  $validators{$ident}->{'modencode:sequence_file'} = new ModENCODE::Validator::Data::dbEST_gi();
  #$validators{$ident}->{'modencode:WIG'} = new ModENCODE::Validator::Data::WIG();
}

sub merge {
  my ($self, $experiment) = @_;
  $experiment = $experiment->clone();
  
  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      # Do we need to check input data? Maybe, but be careful of rescanning input/output data filling the same role
      foreach my $output_datum (@{$applied_protocol->get_output_data()}) {
        my $output_datum_type = $output_datum->get_type();
        my $parser_module = $output_datum_type->get_cv()->get_name() . ":" . $output_datum_type->get_name();
        my $validator = $validators{ident $self}->{$parser_module};
        next unless $validator;
        my $newdatum = $validator->merge($output_datum);
        croak "Cannot merge data columns if they do not validate" unless $newdatum;
        $output_datum->mimic($newdatum);
      }
    }
  }
  return $experiment;
}

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
      foreach my $output_datum (@{$applied_protocol->get_output_data()}) {
        my $output_datum_type = $output_datum->get_type();
        my $parser_module = $output_datum_type->get_cv()->get_name() . ":" . $output_datum_type->get_name();
        my $validator = $validators{ident $self}->{$parser_module};
        if (!$validator) {
          log_error "No validator for data type $parser_module.", "warning";
          next;
        }
        $validator->add_datum($output_datum);
      }
    }
  }
  foreach my $validator (values(%{$validators{ident $self}})) {
    if (!$validator->validate()) {
      return 0;
    }
  }
  return 1;
}

1;
