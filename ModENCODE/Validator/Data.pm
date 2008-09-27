package ModENCODE::Validator::Data;
=pod

=head1 NAME

ModENCODE::Validator::Data - Delegator used to apply validators to BIR-TAB data
columns.

=head1 SYNOPSIS

This class is designed to be run on an
L<Experiment|ModENCODE::Chado::Experiment> object. It will then call any of the
validators defined in the L<Class::Std> L</BUILD()> method on the appropriate
data columns. To add new third-party data validators, you should extend this
class and just overried the C<BUILD> method to attach the additional data
validators.

=head1 USAGE

=head2 Extending for Other Modules

The L</BUILD()> method sets the contents of the C<%validators{ident $self}>
hash. The keys of the hash are the L<CVTerm|ModENCODE::Chado::CVTerm> types of
the attribute column (e.g. C<SO:transcript>). The value of the hash is the
validator that should be run on any columns with that type. For instance:

  $validators{$ident}->{'SO:transcript'} = new ModENCODE::Validator::Data::SO_transcript();

The above line specifies that the L<ModENCODE::Validator::Data::SO_transcript>
validator should be used on any data column that with a
L<CVTerm|ModENCODE::Chado::CVTerm> type of C<SO:transcript>. Each value in the
data column will be added to the validator using its
L<add_attribute|ModENCODE::Validator::Data::Data/add_datum($datum,
$applied_protocol)> method.

=head2 Running

  my $data_validator = new ModENCODE::Validator::Data();
  my $success = $data_validator->validate($experiment);
  if ($success) {
    $experiment = $data_validator->merge($experiment);
  }

Once a ModENCODE::Validator::Data object (or extending subclass) has been
created, you can validate the data columns associated with all L<applied
protocols|ModENCODE::Chado::AppliedProtocol> in an
L<Experiment|ModENCODE::Chado::Experiment> object by using the
</validate($experiment)> method and then merge in any changes made by the
validators using L</merge($experiment)>.

=head1 FUNCTIONS

=over

=item BUILD()

Constructor called on any objects created by L<Class::Std>. See the
documentation for L<Class::Std/BUILD()> for more information on when this method
is called. In this class, it is used to define which data validators should be
used for which columns. (See L<Extending for Other Modules|/Extending for Other
Modules>.) Note that every C<BUILD> method in the class hierarchy will be
called, so if you don't want to use the default validators in a subclass, you'll
want to clean out the C<%validators{ident $self}> hash.

=item validate($experiment)

Collects all of the data columns associated with any L<applied
protocols|ModENCODE::Chado::AppliedProtocol> in the
L<Experiment|ModENCODE::Chado::Experiment> object in C<$experiment>. For each
L<ModENCODE::Chado::Data> found, it calls the
L<add_datum|ModENCODE::Validator::Data::Data/add_datum($datum,
$applied_protocol)> method of any validator defined in the C<%validators{ident
$self}> hash for the datums's L<CVTerm|ModENCODE::Chado::CVTerm> type. Once all
data have been apportioned to their appropriate validator(s), the
L<validate()|ModENCODE::Validator::Data::Data/validate()> method of each
validator is called. If all of the C<validate> calls return true, then this
C<validate($experiment)> call returns 1, otherwise it returns 0.

For any datum with no validator associated with the type, a warning is printed
and the datum is left untouched, assumed to be a free text field.

=item merge($experiment)

Collects all of the data columns associated with any L<applied
protocols|ModENCODE::Chado::AppliedProtocol> in the
L<Experiment|ModENCODE::Chado::Experiment> object in C<$experiment>. For each
L<ModENCODE::Chado::Data> found, it calls the
L<add_datum|ModENCODE::Validator::Data::Data/add_datum($datum,
$applied_protocol)> method of any validator defined in the C<%validators{ident
$self}> hash for the datums's L<CVTerm|ModENCODE::Chado::CVTerm> type. Once all
data have been apportioned to their appropriate mergers(s), the
L<merge()|ModENCODE::Validator::Data::Data/merge()> method of each validator is
called. The C<merge> method of each validator should return the C<$datum>, with
any changes made. The datum object passed in is then updated to match the new
datum, using the L<ModENCODE::Chado::Data/mimic($datum)> method.

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Validator::Attributes::Attributes>,
L<ModENCODE::Chado::Attribute>, L<ModENCODE::Chado::DBXref>,
L<ModENCODE::Chado::CVTerm>, L<ModENCODE::Chado::Experiment>,
L<ModENCODE::Chado::AppliedProtocol>, L<ModENCODE::Validator::Data::Data>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use ModENCODE::Validator::Data::CEL;
use ModENCODE::Validator::Data::BED;
use ModENCODE::Validator::Data::WIG;
use ModENCODE::Validator::Data::dbEST_acc;
use ModENCODE::Validator::Data::Result_File;
use ModENCODE::Validator::Data::GFF3;
use ModENCODE::Validator::Data::SO_transcript;
use ModENCODE::Validator::Data::dbEST_acc_list;
use ModENCODE::Validator::Data::TA_acc;
use ModENCODE::Validator::Data::URL_mediawiki_expansion;
#use ModENCODE::Validator::Data::NCBITrace;
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::ErrorHandler qw(log_error);

my %validators                  :ATTR( :get<validators>,                :default<{}> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  # TODO: Figure out how to be more canonical about CV names w/ respect to validation function identifiers
  $validators{$ident}->{'modencode:CEL'} = new ModENCODE::Validator::Data::CEL({ 'data_validator' => $self });
  $validators{$ident}->{'modencode:transcriptional_fragment_map'} = new ModENCODE::Validator::Data::BED({ 'data_validator' => $self });
  $validators{$ident}->{'modencode:Browser_Extensible_Data_Format (BED)'} = new ModENCODE::Validator::Data::BED({ 'data_validator' => $self });
  $validators{$ident}->{'modencode:WIG'} = new ModENCODE::Validator::Data::WIG({ 'data_validator' => $self });
  $validators{$ident}->{'modencode:Signal_Graph_File'} = new ModENCODE::Validator::Data::WIG({ 'data_validator' => $self });
  $validators{$ident}->{'modencode:dbEST_record'} = new ModENCODE::Validator::Data::dbEST_acc({ 'data_validator' => $self });
  $validators{$ident}->{'modencode:GFF3'} = new ModENCODE::Validator::Data::GFF3({ 'data_validator' => $self });
  $validators{$ident}->{'modencode:accession_number_list_data_file'} = new ModENCODE::Validator::Data::dbEST_acc_list({ 'data_validator' => $self });
  $validators{$ident}->{'SO:transcript'} = new ModENCODE::Validator::Data::SO_transcript({ 'data_validator' => $self });
  $validators{$ident}->{'Result File'} = new ModENCODE::Validator::Data::Result_File({ 'data_validator' => $self });
  $validators{$ident}->{'modencode:TraceArchive_record'} = new ModENCODE::Validator::Data::TA_acc({ 'data_validator' => $self });
  $validators{$ident}->{'URL_mediawiki_expansion'} = new ModENCODE::Validator::Data::URL_mediawiki_expansion({ 'data_validator' => $self });
}

sub merge {
  my ($self, $experiment) = @_;
  #$experiment = $experiment->clone();

  log_error "Merging data elements into experiment object.", "notice", ">";
  
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

    if (!$validator && $datum->get_termsource() && $datum->get_termsource()->get_db()) {
      my $datum_termsource_type = $datum->get_termsource()->get_db()->get_description();
      $validator =  $validators{ident $self}->{$datum_termsource_type};
    }

    next unless $validator;
    my $newdatum = $validator->merge($datum, $applied_protocol);
    croak "Cannot merge data columns if they do not validate" unless $newdatum;
    $datum->mimic($newdatum);
  }
  log_error "Done.", "notice", "<";
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

    # Special case: Any field with a heading of "Result File" should be checked as a generic data file
    if ($datum->get_heading() =~ m/Result *Files?/i) {
      my $file_validator = $validators{ident $self}->{'Result File'};
      $file_validator->add_datum($datum, $applied_protocol);
#      if (!$file_validator->validate()) {
#        $success = 0;
#      }
    }

    my $validator = $self->get_validator_for_type($datum_type);

    if (!$validator && $datum->get_termsource() && $datum->get_termsource()->get_db()) {
      my $datum_termsource_type = $datum->get_termsource()->get_db()->get_description();
      $validator =  $validators{ident $self}->{$datum_termsource_type};
    }

    # If there wasn't a specified validator for this data type, continue
    if (!$validator) {
      log_error "No validator for data type $parser_module.", "warning";
      next;
    } else {
#	log_error "Validator for $parser_module to be used.","notice";
    }
#    print STDERR "adding validator datum: " . $datum->get_value() . " \n";
    $validator->add_datum($datum, $applied_protocol);
  }
  foreach my $validator (values(%{$validators{ident $self}})) {
    if (scalar(@{$validator->get_data()})) {
#	print STDERR "----Validator " . ref($validator) . " running...\n";
      if (!$validator->validate()) {
        $success = 0;
      }
    }
  }
  return $success;
}

1;
