package ModENCODE::Validator::Data;
use strict;
use ModENCODE::Validator::Data::BED;
use ModENCODE::Validator::Data::dbEST_acc;
use ModENCODE::Validator::Data::Result_File;
use ModENCODE::Validator::Data::GFF3;
use ModENCODE::Validator::Data::SO_transcript;
#use ModENCODE::Validator::Data::NCBITrace;
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::ErrorHandler qw(log_error);

my %validators                  :ATTR( :get<validators>,                :default<{}> );

sub START {
  my ($self, $ident, $args) = @_;
  # TODO: Figure out how to be more canonical about CV names w/ respect to validation function identifiers
  $validators{$ident}->{'modencode:Browser_Extensible_Data_Format (BED)'} = new ModENCODE::Validator::Data::BED({ 'data_validator' => $self });
  $validators{$ident}->{'modencode:dbEST_record'} = new ModENCODE::Validator::Data::dbEST_acc({ 'data_validator' => $self });
  $validators{$ident}->{'modencode:GFF3'} = new ModENCODE::Validator::Data::GFF3({ 'data_validator' => $self });
  $validators{$ident}->{'SO:transcript'} = new ModENCODE::Validator::Data::SO_transcript({ 'data_validator' => $self });
  $validators{$ident}->{'Result File'} = new ModENCODE::Validator::Data::Result_File({ 'data_validator' => $self });
  #$validators{$ident}->{'modencode:WIG'} = new ModENCODE::Validator::Data::WIG({ 'data_validator' => $self });
}

sub merge {
  my ($self, $experiment) = @_;
  $experiment = $experiment->clone();
  
  my @unique_data;
  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      foreach my $datum (@{$applied_protocol->get_output_data()}, @{$applied_protocol->get_input_data()}) {
        # Actual equality, not ->equals, since we want to validate the data
        if (!scalar(grep { $datum == $_->{'datum'} && $applied_protocol == $_->{'applied_protocol'} } @unique_data)) {
          push @unique_data, { 'datum' => $datum, 'applied_protocol' => $applied_protocol };
        }
      }
    }
  }
  foreach my $datum (@unique_data) {
    my $applied_protocol = $datum->{'applied_protocol'};
    $datum = $datum->{'datum'};
    my $datum_type = $datum->get_type();
    my $validator = $self->get_validator_for_type($datum_type);
    next unless $validator;
    my $newdatum = $validator->merge($datum, $applied_protocol);
    croak "Cannot merge data columns if they do not validate" unless $newdatum;
    $datum->mimic($newdatum);
  }
  return $experiment;
}

sub get_validator_for_type : PRIVATE {
  my ($self, $type) = @_;
  my $cvname = $type->get_cv()->get_name();
  my $cvterm = $type->get_name();

  my @validator_keys = keys(%{$validators{ident $self}});
  foreach my $validator_key (@validator_keys) {
    my ($cv, $term) = split(/:/, $validator_key);
    if ($term eq $cvterm && ModENCODE::Config::get_cvhandler()->cvname_has_synonym($cvname, $cv)) {
      return $validators{ident $self}->{$validator_key};
    }
  }
}

sub validate {
  my ($self, $experiment) = @_;
  $experiment = $experiment->clone();
  my $success = 1;

  # TODO
  # For any field that is a "* File" 
  # For any field with a DBxref's DB description of URL_*
  # Convert to a feature. Need some automatically-loaded handlers here

  my @unique_data;
  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      foreach my $datum (@{$applied_protocol->get_output_data()}, @{$applied_protocol->get_input_data()}) {
        # Actual equality, not ->equals, since we want to validate the data
        if (!scalar(grep { $datum == $_->{'datum'} && $applied_protocol == $_->{'applied_protocol'} } @unique_data)) {
          push @unique_data, { 'datum' => $datum, 'applied_protocol' => $applied_protocol };
        }
      }
    }
  }

  # For any data field with a cvterm of type where there exists a validator module
  foreach my $datum (@unique_data) {
    my $applied_protocol = $datum->{'applied_protocol'};
    $datum = $datum->{'datum'};
    my $datum_type = $datum->get_type();
    my $parser_module = $datum_type->get_cv()->get_name() . ":" . $datum_type->get_name();
    my $validator = $self->get_validator_for_type($datum_type);
    # Special case: Any field with a heading of "Result File" should be checked as a generic data file
    if ($datum->get_heading() =~ m/Result *Files?/i) {
      my $file_validator = $validators{ident $self}->{'Result File'};
      $file_validator->add_datum($datum, $applied_protocol);
      if (!$file_validator->validate()) {
        $success = 0;
      }
    }
    # If there wasn't a specified validator for this data type, continue
    if (!$validator) {
      log_error "No validator for data type $parser_module.", "warning";
      next;
    }
    $validator->add_datum($datum, $applied_protocol);
  }
  foreach my $validator (values(%{$validators{ident $self}})) {
    if (!$validator->validate()) {
      $success = 0;
    }
  }
  return $success;
}

1;
