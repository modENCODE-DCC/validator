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
use ModENCODE::Validator::Data::SAM;
use ModENCODE::Validator::Data::dbEST_acc;
use ModENCODE::Validator::Data::dbEST_acc_list;
#use ModENCODE::Validator::Data::genbank_acc;
use ModENCODE::Validator::Data::Result_File;
use ModENCODE::Validator::Data::GFF3;
use ModENCODE::Validator::Data::GFF3_parse_only;
use ModENCODE::Validator::Data::SO_transcript;
use ModENCODE::Validator::Data::SO_protein;
use ModENCODE::Validator::Data::GEO_lite;
use ModENCODE::Validator::Data::AE_lite;
use ModENCODE::Validator::Data::SRA_lite;
use ModENCODE::Validator::Data::SRA_list_lite;
#use ModENCODE::Validator::Data::SRA_acc_new;
use ModENCODE::Validator::Data::TA_acc;
use ModENCODE::Validator::Data::URL_mediawiki_expansion;
use ModENCODE::Validator::Data::AntibodyQC;
use ModENCODE::Validator::Data::ReferencedData;
use ModENCODE::Validator::Data::ReferencedFile;
use ModENCODE::Validator::Data::ReadCount;
use ModENCODE::Validator::Data::ReadCount::UniquelyMappedReadCount;
use ModENCODE::Validator::Data::ReadCount::MultiplyMappedReadCount;
use ModENCODE::Validator::Data::ReadCount::ReadCount;
use ModENCODE::Validator::Data::UIC_File;
use ModENCODE::Validator::Data::SAMBAM;

use Class::Std;
use Carp qw(croak carp);
use ModENCODE::ErrorHandler qw(log_error);

my %termsource_validators       :ATTR( :default<{}> );
my %type_validators             :ATTR( :default<{}> );
my %sum_validators              :ATTR( :default<{}> );
my %experiment                  :ATTR( :name<experiment> );

sub START {
  my ($self, $ident, $args) = @_;
  $type_validators{$ident}->{'modencode:CEL'} = new ModENCODE::Validator::Data::CEL({ 'experiment' => $self->get_experiment });
  $type_validators{$ident}->{'modencode:transcriptional_fragment_map'} = new ModENCODE::Validator::Data::BED({ 'experiment' => $self->get_experiment });
  $type_validators{$ident}->{'modencode:Browser_Extensible_Data_Format (BED)'} = new ModENCODE::Validator::Data::BED({ 'experiment' => $self->get_experiment });
  $type_validators{$ident}->{'modencode:WIG'} = new ModENCODE::Validator::Data::WIG({ 'experiment' => $self->get_experiment });
  $type_validators{$ident}->{'modencode:Sequence_Alignment/Map (SAM)'} = new ModENCODE::Validator::Data::SAMBAM({ 'experiment' => $self->get_experiment });
  $type_validators{$ident}->{'modencode:Binary Sequence_Alignment/Map (BAM)'} = new ModENCODE::Validator::Data::SAMBAM({ 'experiment' => $self->get_experiment });
  $type_validators{$ident}->{'modencode:Signal_Graph_File'} = new ModENCODE::Validator::Data::WIG({ 'experiment' => $self->get_experiment });
  $type_validators{$ident}->{'modencode:GFF3'} = new ModENCODE::Validator::Data::GFF3({ 'experiment' => $self->get_experiment });
  $type_validators{$ident}->{'modencode:GFF3 (parse only)'} = new ModENCODE::Validator::Data::GFF3_parse_only({ 'experiment' => $self->get_experiment });
  $type_validators{$ident}->{'modencode:dbEST_record'} = new ModENCODE::Validator::Data::dbEST_acc({ 'experiment' => $self->get_experiment });
  #$type_validators{$ident}->{'modencode:genbank_record'} = new ModENCODE::Validator::Data::genbank_acc({ 'experiment' => $self->get_experiment });
  $type_validators{$ident}->{'modencode:accession_number_list_data_file'} = new ModENCODE::Validator::Data::dbEST_acc_list({ 'experiment' => $self->get_experiment });
  $type_validators{$ident}->{'SO:transcript'} = new ModENCODE::Validator::Data::SO_transcript({ 'experiment' => $self->get_experiment });
  $type_validators{$ident}->{'SO:protein'} = new ModENCODE::Validator::Data::SO_protein({ 'experiment' => $self->get_experiment });
  $type_validators{$ident}->{'modencode:TraceArchive_record'} = new ModENCODE::Validator::Data::TA_acc({ 'experiment' => $self->get_experiment });
  $type_validators{$ident}->{'modencode:GEO_record'} = new ModENCODE::Validator::Data::GEO_lite({ 'experiment' => $self->get_experiment });
  $type_validators{$ident}->{'modencode:ArrayExpress_record'} = new ModENCODE::Validator::Data::GEO_lite({ 'experiment' => $self->get_experiment });
  $type_validators{$ident}->{'modencode:ShortReadArchive_project_ID (SRA)'} = new ModENCODE::Validator::Data::SRA_lite({ 'experiment' => $self->get_experiment });
#  $type_validators{$ident}->{'modencode:ShortReadArchive_project_ID (SRA)'} = new ModENCODE::Validator::Data::SRA_acc_new({ 'experiment' => $self->get_experiment });
  $type_validators{$ident}->{'modencode:ShortReadArchive_project_ID_list (SRA)'} = new ModENCODE::Validator::Data::SRA_list_lite({ 'experiment' => $self->get_experiment });
  $type_validators{$ident}->{'mged:antibody'} = new ModENCODE::Validator::Data::AntibodyQC({ 'experiment' => $self->get_experiment });

  my $uic_config = ModENCODE::Config::get_cfg()->SectionExists('remote_file_storage');
  if ($uic_config) {
    $uic_config = ModENCODE::Config::get_cfg();
    my $args = {
      "transfer_host" => $uic_config->val("remote_file_storage", "host"),
      "remote_url_prefix" => $uic_config->val("remote_file_storage", "remote_url_prefix"),
      "local_web_prefix" => $uic_config->val("remote_file_storage", "local_web_prefix"),
      "transfer_cmd" => $uic_config->val("remote_file_storage", "remote_transfer_daemon"),
      "remote_user" => $uic_config->val("remote_file_storage", "remote_user"),
      "identity_file" => $uic_config->val("remote_file_storage", "identity_file"),
      "experiment" => $self->get_experiment
    };

    $type_validators{$ident}->{'modencode:FASTQ'} = new ModENCODE::Validator::Data::UIC_File($args);
    $type_validators{$ident}->{'modencode:SFF'} = new ModENCODE::Validator::Data::UIC_File($args);
    $type_validators{$ident}->{'modencode:SRA'} = new ModENCODE::Validator::Data::UIC_File($args);
  }

  $termsource_validators{$ident}->{'URL_mediawiki_expansion'} = new ModENCODE::Validator::Data::URL_mediawiki_expansion({ 'experiment' => $self->get_experiment });
  $sum_validators{$ident}->{'modencode:read_count'} = new ModENCODE::Validator::Data::ReadCount::ReadCount({ 'experiment' => $self->get_experiment });
  $sum_validators{$ident}->{'modencode:uniquely_mapped_read_count'} = new ModENCODE::Validator::Data::ReadCount::UniquelyMappedReadCount({ 'experiment' => $self->get_experiment });
  $sum_validators{$ident}->{'modencode:multiply_mapped_read_count'} = new ModENCODE::Validator::Data::ReadCount::MultiplyMappedReadCount({ 'experiment' => $self->get_experiment });
}


sub get_validator_for_type : PRIVATE {
  my ($self, $type) = @_;
  my $cvname = $type->get_cv(1)->get_name();
  my $cvterm = $type->get_name();


  my @validator_keys = keys(%{$type_validators{ident $self}});
  foreach my $validator_key (@validator_keys) {
    my ($cv, $term) = split(/:/, $validator_key);
    if ($term eq $cvterm && ModENCODE::Config::get_cvhandler()->cvname_has_synonym($cvname, $cv)) {
      return $type_validators{ident $self}->{$validator_key};
    }
  }
}

sub get_sum_validator_for_type : PRIVATE {
  my ($self, $type) = @_;
  my $cvname = $type->get_cv(1)->get_name();
  my $cvterm = $type->get_name();


  my @validator_keys = keys(%{$sum_validators{ident $self}});
  foreach my $validator_key (@validator_keys) {
    my ($cv, $term) = split(/:/, $validator_key);
    if ($term eq $cvterm && ModENCODE::Config::get_cvhandler()->cvname_has_synonym($cvname, $cv)) {
      return $sum_validators{ident $self}->{$validator_key};
    }
  }
}

sub validate {
  my $self = shift;
  my $success = 1;
  my $experiment = $self->get_experiment;

  # For any field that is a "* File" 
  # For any field with a DBxref's DB description of URL_*
  # Convert to a feature. Need some automatically-loaded handlers here

  my @all_data;
  foreach my $applied_protocol_slot (@{$experiment->get_applied_protocol_slots}) {
    foreach my $applied_protocol (@$applied_protocol_slot) {
      push @all_data, map { [ $applied_protocol, 'input', $_ ] } $applied_protocol->get_input_data;
      push @all_data, map { [ $applied_protocol, 'output', $_ ] } $applied_protocol->get_output_data;
    }
  }
  my %seen;
  my @all_data_with_dups = grep { !$seen{$_->[0]->get_id . '.' . $_->[1] . '.' . $_->[2]->get_id . '.' . join(",", map { $_->get_id } $_->[0]->get_output_data(1))    }++ } @all_data;
  undef %seen;
  @all_data = grep { !$seen{$_->[0]->get_id . '.' . $_->[1] . '.' . $_->[2]->get_id}++ } @all_data;

  log_error "There are " . scalar(@all_data) . " unique data/applied protocol pairs found.", "debug", ">";

  # Preprocess any Result File column which will fetch files at remote URLs, etc.
  my $file_validator = new ModENCODE::Validator::Data::Result_File({ 'experiment' => $self->get_experiment });
  foreach my $ap_datum (@all_data) {
    my ($applied_protocol, $direction, $datum) = @$ap_datum;
    if (
      $datum->get_object->get_heading() =~ m/Result *Files?/i ||
      $datum->get_object->get_heading() =~ m/Parameter *Files?/i ||
      $datum->get_object->get_heading() =~ m/Array *Data *Files?/i ||
      $datum->get_object->get_heading() =~ m/Array *Matrix *Data *Files?/i ||
      $datum->get_object->get_heading() =~ m/(Derived)? Array *Data *Files?/i
    ) {
      if ($datum->get_object->get_termsource() && $datum->get_object->get_termsource(1)->get_db(1)->get_description() =~ /modencode_submission(_quick)?/) {
        log_error "Not checking for local presence of referenced file " . $datum->get_object->get_value()  . ".", "notice";
      } else {
        $file_validator->add_datum_pair($ap_datum);
      }
    }
  }
  if ($file_validator->num_data) {
    $success = 0 unless $file_validator->validate();
  }

  # For any data field with a cvterm of type where there exists a validator module
  my $need_to_sum = 0;
  foreach my $ap_datum (@all_data) {

    my ($applied_protocol, $direction, $datum) = @$ap_datum;
    log_error $applied_protocol->get_protocol(1)->get_name . " has $direction datum " . $datum->get_object->get_heading . " [" . $datum->get_object->get_name .  "].", "debug";

    my $datum_type = $datum->get_object->get_type(1);
    my $validator;

    if (!$need_to_sum) {
      $need_to_sum = 1 if $self->get_sum_validator_for_type($datum_type);
    }

    if ($datum_type) {
      $validator = $self->get_validator_for_type($datum_type);
    }


    my $datum_termsource_type;
    if ($datum->get_object->get_termsource) {
      # Fall back to validating by term source
      $datum_termsource_type = $datum->get_object->get_termsource(1)->get_db(1)->get_description();
      if (!$validator) {
        $validator =  $termsource_validators{ident $self}->{$datum_termsource_type};
      }
    }

    # Throw a warning if a field looks like a wiki URL but doesn't have an appropriate termsource
    if ($datum->get_object->get_value =~ /oldid=/ && $datum_termsource_type ne 'URL_mediawiki_expansion') {
      log_error "It looks like you meant to provide a reference to a wiki URL " . $datum->get_object->get_value . " in the " . 
      $datum->get_object->get_heading . " [" . $datum->get_object->get_name . "] field in the SDRF, but it doesn't have a Term Source REF " .
      "of type URL_mediawiki_expansion!", "error";
      $success = 0;
    }

    # If there wasn't a specified validator for this data type, continue
    if (!$validator && !$datum->get_object->is_anonymous) {
      my $message = "No validator for";
      $message .= " datum type " . (($datum_type) ?  $datum_type->get_cv(1)->get_name . ":" . $datum_type->get_name : "(no type)");
      $message .= " with termsource " . (($datum_termsource_type) ? $datum_termsource_type : "(no termsource)");
      $message .= " " . $datum->get_object->get_heading . " [" . $datum->get_object->get_name . "].";
      log_error $message, "warning";
      next;
    } elsif (!$validator) {
      next;
    }
    unless ($datum->get_object->get_termsource() && $datum->get_object->get_termsource(1)->get_db(1)->get_description() =~ /modencode_submission(_quick)?/) {
      $validator->add_datum_pair($ap_datum);
    }
  }
  if ($need_to_sum) {
    foreach my $ap_datum (@all_data_with_dups) {
      # Summation validators require access to all copies of a datum
      my ($applied_protocol, $direction, $datum) = @$ap_datum;
      log_error $applied_protocol->get_protocol(1)->get_name . " has non-unique $direction datum " . $datum->get_object->get_heading . " [" . $datum->get_object->get_name .  "].", "debug";

      my $datum_type = $datum->get_object->get_type(1);
      my $validator;

      if ($datum_type) {
        $validator = $self->get_sum_validator_for_type($datum_type);
        $validator->add_datum_pair($ap_datum) if ($validator);
      }
    }
  }
  log_error "Done adding applied_protocol/data pairs to validators.", "debug", "<";

  log_error "Running validators.", "notice", ">";
  foreach my $validator (values(%{$termsource_validators{ident $self}}), values(%{$type_validators{ident $self}}), values(%{$sum_validators{ident $self}})) {
    if ($validator->num_data() && !$validator->validate()) {
      return 0;
    }
  }

  # Check for data referenced in other submissions
  my $referenced_datum_validator = new ModENCODE::Validator::Data::ReferencedData({ 'experiment' => $self->get_experiment });
  my $referenced_file_validator = new ModENCODE::Validator::Data::ReferencedFile({ 'experiment' => $self->get_experiment });
  foreach my $ap_datum (@all_data) {
    my ($applied_protocol, $direction, $datum) = @$ap_datum;
    unless ($datum->get_object->get_type(1)) {
      log_error "No type defined in wiki for $direction " . $datum->get_object->get_heading . " [" . $datum->get_object->get_name . "] of protocol " . $applied_protocol->get_protocol(1)->get_name() . "!", "error";
      return 0;
    }
    my $type_name = $datum->get_object->get_type(1)->get_cv(1)->get_name . ":" . $datum->get_object->get_type(1)->get_name;
    next if $type_name eq "SO:transcript"; # Custom handler for transcripts
    if ($datum->get_object->get_termsource() && $datum->get_object->get_termsource(1)->get_db(1)->get_description() =~ /modencode_submission(_quick)?/) {
      if (
        $datum->get_object->get_heading() =~ m/Result *Files?/i ||
        $datum->get_object->get_heading() =~ m/Parameter *Files?/i ||
        $datum->get_object->get_heading() =~ m/Array *Data *Files?/i ||
        $datum->get_object->get_heading() =~ m/Array *Matrix *Data *Files?/i ||
        $datum->get_object->get_heading() =~ m/(Derived)? Array *Data *Files?/i
      ) {
        $referenced_file_validator->add_datum_pair($ap_datum);
      } else {
        $referenced_datum_validator->add_datum_pair($ap_datum);
      }
    }
  }
  if ($referenced_datum_validator->num_data) {
    $success = 0 unless $referenced_datum_validator->validate();
  }
  if ($referenced_file_validator->num_data) {
    $success = 0 unless $referenced_file_validator->validate();
  }




  log_error "Done.", "notice", "<";
  return $success;
}

1;
