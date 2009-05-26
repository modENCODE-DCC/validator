package ModENCODE::Validator::IDF_SDRF;
=pod

=head1 NAME

ModENCODE::Validator::IDF_SDRF - Validator that will validate a BIR-TAB IDF
document against SDRF document(s) and return a merged
L<Experiment|ModENCODE::Chado::Experiment> object.

=head1 SYNOPSIS

This class should be used to work with the output of L<ModENCODE::Parser::IDF>
and L<ModENCODE::Parser::SDRF>. Instances of this validator should be
initialized with the L<experiment|ModENCODE::Chado::Experiment>,
L<protocols|ModENCODE::Chado::Protocol>, and L<dbxref|ModENCODE::Chado::DBXref>s
returned by the L<ModENCODE::Parser::IDF/parse($document)> method, and then used
to validate the SDRF experiment object(s).

=head1 USAGE

To initialize the validator:

  my $parser = new ModENCODE::Parser::IDF();
  my ($experiment, $protocols, $sdrfs, $dbxrefs) = $parser->parse('IDF.txt');
  my $idf_sdrf_validator = new ModENCODE::Validator::IDF_SDRF({
    'idf_experiment' => $experiment,
    'protocols' => $protocols,
    'termsources' => $dbxrefs
  });

(You can also use L<set_idf_experiment($experiment)|/get_idf_experiment() |
set_idf_experiment($experiment)>, L<set_protocols($protocols)|/get_protocols() |
set_protocols($protocols)>, and/or
L<set_termsources($termsources)|/get_termsources() |
set_termsources($termsources)> to set the values after the object has been
created.)

Once you've initialized the validator, you should validate and merge all of the
SDRF L<Experiment|ModENCODE::Chado::Experiment> objects:

  foreach my $sdrf (@$sdrfs) {
    if ($idf_sdrf_validator->validate($sdrf)) {
      $experiment = $idf_sdrf_validator->merge($sdrf);
      $idf_sdrf_validator->set_experiment($experiment);
    } else {
      die "Couldn't validate " . $sdrf->to_string();
    }
  }

=head1 VALIDATION AND MERGING

=head2 Validation

During the validation step, this validator checks that:

=begin html

<ul>
  <li>All protocols in the SDRF are defined in the IDF.</li>
  <li>All input data to protocols mentioned in the IDF are used in the SDRF
      (and vice versa)</li>
  <li>All values in C<Term Source REF> columns in the SDRF are defined as term
      sources in the IDF.</li>
</ul>

=end html

=begin roff

=over

=item * All protocols in the SDRF are defined in the IDF.

=item * All input data to protocols mentioned in the IDF are used in the SDRF
(and vice versa)

=item * All values in C<Term Source REF> columns in the SDRF are defined as term
sources in the IDF.

=back

=end roff

=head2 Merging

During the merging step, this validator returns an
L<Experiment|ModENCODE::Chado::Experiment> object with:

=begin html

<ul>
  <li>Experiment properties with a controlled term from a term source
      (L<DBXref|ModENCODE::Chado::DBXref>) are updated to include the
      L<DB|ModENCODE::Chado::DB> object for the term source.</li>
  <li>Protocol objects from columns in the SDRF are merged with the protocol
      definitions in the IDF to include the protocol
      L<Attributes|ModENCODE::Chado::Attributes>, description, definition,
      etc.</li>
  <li>If there are outputs from previous L<applied
      protocol|ModENCODE::Chado::AppliedProtocol>s that act as implied inputs to
      other applied protocols, they are removed unless they are specifically
      mentioned as inputs in the IDF.</li>
  <li>Any Term Source REF fields in the SDRF are processed to include the
      L<DB|ModENCODE::Chado::DB> object for the term source.</li>
</ul>

=end html

=begin roff

=over

=item * Experiment properties with a controlled term from a term source
(L<DBXref|ModENCODE::Chado::DBXref>) are updated to include the
L<DB|ModENCODE::Chado::DB> object for the term source.

=item * Protocol objects from columns in the SDRF are merged with the protocol
definitions in the IDF to include the protocol
L<Attributes|ModENCODE::Chado::Attributes>, description, definition, etc.

=item * If there are outputs from previous L<applied
protocol|ModENCODE::Chado::AppliedProtocol>s that act as implied inputs to other
applied protocols, they are removed unless they are specifically mentioned as
inputs in the IDF.

=item * Any Term Source REF fields in the SDRF are processed to include the
L<DB|ModENCODE::Chado::DB> object for the term source.

=back

=end roff

=head1 FUNCTIONS

=over

=item get_idf_experiment() | set_idf_experiment($experiment)

Get the current L<ModENCODE::Chado::Experiment> object that is being used as the
base IDF experiment object, or set the IDF experiment to C<$experiment>.

=item get_protocols() | set_protocols($protocols)

Get the current arrayref of L<ModENCODE::Chado::Protocol> objects that are being
used as the list of protocol definitions from the IDF, or set the list to
C<$protocols>.

=item get_termsources() | set_termsources($termsources)

Get the current arrayref of L<ModENCODE::Chado::DBXref> objects that are being
used as the list of term source definitions from the IDF, or set the list to
C<$termsources>.

=item validate($experiment)

Ensures that the IDF L<experiment|ModENCODE::Chado::Experiment>,
L<protocols|ModENCODE::Chado::Protocol>, and
L<termsources|ModENCODE::Chado::DBXref> are consistent with the SDRF
L<experiment|ModENCODE::Chado::Experiment> in C<$experiment>. For more
information, see L</Validation>.

=item merge($experiment)

Merges the IDF L<experiment|ModENCODE::Chado::Experiment>,
L<protocols|ModENCODE::Chado::Protocol>, and
L<termsources|ModENCODE::Chado::DBXref> and the SDRF
L<experiment|ModENCODE::Chado::Experiment> in C<$experiment> into a new
L<Experiment|ModENCODE::Chado::Experiment> object, which is returned. For more
information, see L</Merging>.

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Validator::Attributes>,
L<ModENCODE::Validator::Data>, L<ModENCODE::Validator::ModENCODE_Projects>,
L<ModENCODE::Validator::TermSources>, L<ModENCODE::Validator::Wiki>,
L<ModENCODE::Chado::Attribute>, L<ModENCODE::Chado::DBXref>,
L<ModENCODE::Chado::Experiment>, L<ModENCODE::Chado::AppliedProtocol>,
L<ModENCODE::Chado::Data>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use Class::Std;
use Carp qw(croak);
use ModENCODE::ErrorHandler qw(log_error);


my %idf_experiment   :ATTR( :name<idf_experiment> );
my %sdrf_experiment  :ATTR( :name<sdrf_experiment> );
my %protocols        :ATTR( :name<protocols> );
my %termsources      :ATTR( :name<termsources> );

sub validate {
  my $self = shift;
  croak "Cannot validate without an IDF object. Please call " .  ref($self) . "->set_idf_experiment(\$idf_experiment)" unless $self->get_idf_experiment();
  croak "Cannot validate without an SDRF object. Please call " .  ref($self) . "->set_sdrf_experiment(\$sdrf_experiment)" unless $self->get_sdrf_experiment();
  croak "Cannot validate an SDRF without any protocol objects. Please call " .  ref($self) . "->set_protocols(\\\@protocols)" unless scalar(@{$self->get_protocols()});
  my $success = 1;

  my $sdrf_experiment = $self->get_sdrf_experiment();

  # Collect lists of the SDRF applied protocols and unique protocols
  my @sdrf_applied_protocols;
  foreach my $applied_protocol_slots (@{$sdrf_experiment->get_applied_protocol_slots()}) {
    push @sdrf_applied_protocols, (@$applied_protocol_slots);
  }

  # Get the unique protocols from the sdrf_experiment
  my %seen;
  my @sdrf_protocols = grep { !$seen{$_->get_object->get_name()}++ } map { $_->get_protocol() } @sdrf_applied_protocols;

  # Make sure that all protocols in the SDRF are defined in the IDF
  my @undefined_protocols;
  foreach my $sdrf_protocol (@sdrf_protocols) {
    my ($idf_protocol) = grep { $_->get_object->get_name() eq $sdrf_protocol->get_object->get_name() } @{$self->get_protocols()};
    if (!$idf_protocol) {
      push @undefined_protocols, $sdrf_protocol;
    }
  }
  if (scalar(@undefined_protocols)) {
    log_error "The following protocol(s) are referred to in the SDRF but not defined in the IDF!\n  '" . join("', '", map { $_->get_object->get_name() } @undefined_protocols) . "'.";
    $success = 0;
    return $success;
  }

  # Parameters
  # Make sure all the protocol parameters in the IDF exist in the SDRF and vice versa
  #   First all of the parameters (by protocol) used in the SDRF from Protocol Attributes, Data, and Data Attributes
  #   $named_fields = { "protocol1" => [ 'param1', 'param2' ] }
  my %named_fields;
  foreach my $applied_protocol (@sdrf_applied_protocols) {
    my $protocol = $applied_protocol->get_protocol();
    my $protocol_name = $protocol->get_object->get_name();
    $named_fields{$protocol_name} = [] unless defined($named_fields{$protocol_name});

    foreach my $protocol_attribute ($protocol->get_object->get_attributes(1)) {
      if (defined($protocol_attribute->get_name()) && length($protocol_attribute->get_name())) {
        push @{$named_fields{$protocol_name}}, $protocol_attribute->get_name();
      }
    }
    foreach my $datum ($applied_protocol->get_input_data(1)) {
      if (defined($datum->get_name()) && length($datum->get_name())) {
        push @{$named_fields{$protocol_name}}, $datum->get_name();
      }
      foreach my $datum_attribute ($datum->get_attributes(1)) {
        if (defined($datum_attribute->get_name()) && length($datum_attribute->get_name())) {
          push @{$named_fields{$protocol_name}}, $datum_attribute->get_name();
        }
      }
    }
  }

  # Now make sure all of the named fields in the SDRF are in the IDF
  foreach my $idf_protocol (map { $_->get_object } @{$self->get_protocols()}) {
    my ($parameters) = grep { $_->get_heading() =~ m/^\s*Protocol Parameters?\s*$/ } $idf_protocol->get_attributes(1);
    my @idf_params; @idf_params = split /;/, $parameters->get_value() if (defined($parameters));
    for (my $i = 0; $i < scalar(@idf_params); $i++) {
      $idf_params[$i] =~ s/^\s*|\s*$//g;
    }
    my @sdrf_params = defined($named_fields{$idf_protocol->get_name()}) ? @{$named_fields{$idf_protocol->get_name()}} : ();
    # Make sure all IDF params are in the SDRF
    foreach my $idf_param (@idf_params) {
      my @matching_param = grep { $_ eq $idf_param } @sdrf_params;
      if (!scalar(@matching_param)) {
        log_error "Unable to find the '$idf_param' field in the SDRF even though it is defined in the IDF for the " . $idf_protocol->get_name() . " protocol.";
        $success = 0;
      }
    }
  }

  # Also check to make sure that the Experimental Factor Name is in the SDRF
  my ($exp_factor_name) = grep { $_->get_name eq "Experimental Factor Name" } ($self->get_idf_experiment->get_properties(1));
  my @exp_factor_column = grep { grep { $_ eq $exp_factor_name->get_value } @$_; } values(%named_fields);
  if (!scalar(@exp_factor_column)) {
    # Check attributes since we didn't find a matching datum
    foreach my $applied_protocol_slots (@{$sdrf_experiment->get_applied_protocol_slots()}) {
      foreach my $applied_protocol (@$applied_protocol_slots) {
        foreach my $datum ($applied_protocol->get_input_data(1), $applied_protocol->get_output_data(1)) {
          foreach my $datum_attribute ($datum->get_attributes(1)) {
            if ($datum_attribute->get_name() && $datum_attribute->get_name() eq $exp_factor_name->get_value) {
              push @exp_factor_column, $datum_attribute;
            }
          }
        }
      }
    }
  }
  if (!scalar(@exp_factor_column)) {
    log_error "Unable to find the \"" . $exp_factor_name->get_value . "\" column in the SDRF which has been referenced in the Experimental Factor Name field of the IDF.";
    $success = 0;
  }

  # Term sources
  # Collect unique term source databases from Protocols, Attributes, Datas in the SDRF
  my @sdrf_term_source_dbs;
  foreach my $applied_protocol_slots (@{$sdrf_experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      if ($applied_protocol->get_protocol()) {
        if ($applied_protocol->get_protocol()->get_object->get_termsource() && $applied_protocol->get_protocol()->get_object->get_termsource()->get_object->get_db()) {
          push @sdrf_term_source_dbs, $applied_protocol->get_protocol()->get_object->get_termsource()->get_object->get_db();
        }
        foreach my $attribute ($applied_protocol->get_protocol->get_object->get_attributes(1)) {
          if ($attribute->get_termsource() && $attribute->get_termsource(1)->get_db()) {
            push @sdrf_term_source_dbs, $attribute->get_termsource(1)->get_db();
          }
        }
      }
      foreach my $datum ($applied_protocol->get_input_data(1), $applied_protocol->get_output_data(1)) {
        if ($datum->get_termsource() && $datum->get_termsource(1)->get_db()) {
          push @sdrf_term_source_dbs, $datum->get_termsource(1)->get_db();
        }
        foreach my $attribute ($datum->get_attributes(1)) {
          if ($attribute->get_termsource() && $attribute->get_termsource(1)->get_db()) {
            push @sdrf_term_source_dbs, $attribute->get_termsource(1)->get_db();
          }
        }
      }
    }
  }
  undef %seen;
  @sdrf_term_source_dbs = grep { !$seen{$_->get_id()}++ } @sdrf_term_source_dbs;

  # Get unique term sources databases from IDF
  undef %seen;
  my @idf_term_source_dbs = grep { !$seen{$_->get_id}++ } map { $_->get_object->get_db } @{$self->get_termsources()};

  # Find which ones databases are in the SDRF but not defined in the IDF
  my @undefined_term_sources;
  foreach my $sdrf_term_source_db (@sdrf_term_source_dbs) {
    if (!scalar(grep { $_->get_object->get_name eq $sdrf_term_source_db->get_object->get_name } @idf_term_source_dbs)) {
      push @undefined_term_sources, $sdrf_term_source_db;
    }
  }
  if (scalar(@undefined_term_sources)) {
    log_error "The following term source(s) are referred to in the SDRF but not defined in the IDF!\n  '" . join("', '", map { $_->get_object->get_name() } @undefined_term_sources) . "'.";
    $success = 0;
  }

  # Copy basic experiment attributes from IDF experiment object to SDRF experiment object
  # These aren't attached to the experiment in the cache
  foreach my $property ($self->get_idf_experiment->get_properties) {
    $sdrf_experiment->add_property($property);
  }

  # Parameters
  #   Remove any named "inputs" from applied protocols that aren't listed as protocol parameters in the IDF
  foreach my $sdrf_applied_protocol (@sdrf_applied_protocols) {
    my $sdrf_protocol = $sdrf_applied_protocol->get_protocol();
    my ($idf_protocol) = grep { $_->get_object->get_name() eq $sdrf_protocol->get_object->get_name() } @{$self->get_protocols()};
    my ($parameters) = grep { $_->get_heading() =~ m/^\s*Protocol Parameters?\s*$/ } $idf_protocol->get_object->get_attributes(1);
    my @idf_params; @idf_params = split /;/, $parameters->get_value() if (defined($parameters));
    for (my $i = 0; $i < scalar(@idf_params); $i++) { $idf_params[$i] =~ s/^\s*|\s*$//g; }

    my @data_to_remove;
    foreach my $datum ($sdrf_applied_protocol->get_input_data()) {
      my $datum_obj = $datum->get_object;
      if (defined($datum_obj->get_name) && length($datum_obj->get_name)) {
        my @matching_params = grep { $_ eq $datum_obj->get_name() } @idf_params;
        if (!scalar(@matching_params)) {
          log_error "Removing datum '" . $datum_obj->get_name . "' as input from '" . $sdrf_protocol->get_object->get_name() . "'; not found in IDF's Protocol Parameters.", "warning";
          push @data_to_remove, $datum;
        }
      }
    }
    foreach my $datum (@data_to_remove) {
      # Make sure this isn't the last remaining connection between these two protocols
      $sdrf_applied_protocol->remove_input_datum($datum);
      if (!scalar($sdrf_applied_protocol->get_input_data)) {
        log_error "Removed the last datum that should be acting as the link between the previous protocol and " . $sdrf_protocol->get_object->get_name() . ". Perhaps you forgot to list it as an input in the IDF.", "error";
        $success = 0;
      }
    }
  }

  # Remove the Protocol Parameters attribute from any SDRF protocols
  foreach my $sdrf_protocol (@sdrf_protocols) {
    my @filtered_attributes = grep { $_->get_object->get_heading !~ m/^\s*Protocol *Parameters?/i } $sdrf_protocol->get_object->get_attributes;
    $sdrf_protocol->get_object->set_attributes(\@filtered_attributes);
  }

  return $success ? $sdrf_experiment : 0;
}

1;

