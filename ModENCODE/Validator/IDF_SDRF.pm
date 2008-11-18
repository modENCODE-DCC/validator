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
my %protocols        :ATTR( :name<protocols> );
my %termsources      :ATTR( :name<termsources> );

sub merge {
  my ($self, $sdrf_experiment) = @_;
  #$sdrf_experiment = $sdrf_experiment->clone(); # Don't actually change the SDRF that was passed in
  croak "Can't merge IDF & SDRF unless they validated" unless $self->validate($sdrf_experiment);

  # Update IDF experiment properties with full term sources instead of just term source names
  foreach my $experiment_prop (@{$self->get_idf_experiment()->get_properties()}) {
    if ($experiment_prop->get_termsource()) {
      my ($full_termsource) = grep { $_->get_db()->get_name() eq $experiment_prop->get_termsource()->get_db()->get_name() } @{$self->get_termsources()};
      $experiment_prop->get_termsource()->set_db($full_termsource->get_db());
      $experiment_prop->get_termsource()->set_version($full_termsource->get_version());
    }
  }

  # Copy basic experiment attributes from IDF experiment object to SDRF experiment object
  $sdrf_experiment->add_properties($self->get_idf_experiment()->get_properties());
  $sdrf_experiment->set_uniquename($self->get_idf_experiment()->get_uniquename());

  # Update SDRF protocols with additional information from IDF
  my @sdrf_applied_protocols;
  foreach my $applied_protocol_slots (@{$sdrf_experiment->get_applied_protocol_slots()}) {
    push @sdrf_applied_protocols, (@$applied_protocol_slots);
  }
  my @sdrf_protocols = map { $_->get_protocol() } @sdrf_applied_protocols;;
  # Add any protocol attributes as an attribute (except for Protocol Parameters, which is special)
  foreach my $sdrf_protocol (@sdrf_protocols) {
    my ($idf_protocol) = grep { $_->get_name() eq $sdrf_protocol->get_name() } @{$self->get_protocols()};
    croak "Can't find IDF protocol for SDRF protocol " . $sdrf_protocol->get_name() unless $idf_protocol;
    if (!$idf_protocol) {
	log_error "Can't find IDF protocol for SDRF protocol " . + $sdrf_protocol->get_name(), "error";
    } else {
    if (length($idf_protocol->get_description())) {
      $sdrf_protocol->set_description($idf_protocol->get_description());
      foreach my $attribute (@{$idf_protocol->get_attributes()}) {
        next if $attribute->get_heading() =~ m/^\s*Protocol *Parameters?/i;
        $sdrf_protocol->add_attribute($attribute);
      }
    }
    }
  }
  # Parameters
  #   Remove any named "inputs" from applied protocols that aren't listed as protocol parameters in the IDF
  foreach my $sdrf_applied_protocol (@sdrf_applied_protocols) {
    my $sdrf_protocol = $sdrf_applied_protocol->get_protocol();
    my ($idf_protocol) = grep { $_->get_name() eq $sdrf_protocol->get_name() } @{$self->get_protocols()};
    my ($parameters) = grep { $_->get_heading() =~ m/^\s*Protocol Parameters?\s*$/ } @{$idf_protocol->get_attributes()};
    my @idf_params; @idf_params = split /;/, $parameters->get_value() if (defined($parameters));
    for (my $i = 0; $i < scalar(@idf_params); $i++) {
      $idf_params[$i] =~ s/^\s*|\s*$//g;
    }
    my @data_to_remove;
    foreach my $datum (@{$sdrf_applied_protocol->get_input_data()}) {
      if (defined($datum->get_name()) && length($datum->get_name())) {
        my @matching_params = grep { $_ eq $datum->get_name() } @idf_params;;
        if (!scalar(@matching_params)) {
          log_error "Removing datum '" . $datum->get_name . "' as input from '" . $sdrf_protocol->get_name() . "'; not found in IDF's Protocol Parameters.", "warning";
          push @data_to_remove, $datum;
        }
      }
    }
    foreach my $datum (@data_to_remove) {
      $sdrf_applied_protocol->remove_input_datum($datum);
    }
  }

  # Update SDRF term sources (DBXrefs and their DBs) with information from IDF
  my @sdrf_terms;
  foreach my $applied_protocol_slots (@{$sdrf_experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      if ($applied_protocol->get_protocol()) {
        if ($applied_protocol->get_protocol()->get_termsource() && $applied_protocol->get_protocol()->get_termsource()->get_db()) {
          push @sdrf_terms, $applied_protocol->get_protocol()->get_termsource();
        }
        foreach my $attribute (@{$applied_protocol->get_protocol->get_attributes()}) {
          if ($attribute->get_termsource() && $attribute->get_termsource()->get_db()) {
            push @sdrf_terms, $attribute->get_termsource();
          }
        }
      }
      foreach my $datum (@{$applied_protocol->get_input_data()}, @{$applied_protocol->get_output_data()}) {
        if ($datum->get_termsource() && $datum->get_termsource()->get_db()) {
          push @sdrf_terms, $datum->get_termsource();
        }
        foreach my $attribute (@{$datum->get_attributes()}) {
          if ($attribute->get_termsource() && $attribute->get_termsource()->get_db()) {
            push @sdrf_terms, $attribute->get_termsource();
          }
        }
      }
    }
  }
  foreach my $sdrf_term (@sdrf_terms) {
    my ($idf_term) = grep { $_->get_db()->get_name() eq $sdrf_term->get_db()->get_name() } @{$self->get_termsources()};
    if (!$idf_term) {
      log_error "Cannot find the Term Source REF definition for " . $sdrf_term->get_db()->get_name() . " in the IDF, although it is referenced in the SDRF.", "error";
      exit;
    }
    $sdrf_term->set_db($idf_term->get_db());
    $sdrf_term->set_version($idf_term->get_version());
  }

  return $sdrf_experiment;
}

sub validate {
  my ($self, $sdrf_experiment) = @_;
  croak "Cannot validate an SDRF without an IDF object. Please call " .  ref($self) . "->set_idf_experiment(\$idf_experiment)" unless $self->get_idf_experiment();
  croak "Cannot validate an SDRF without any protocol objects. Please call " .  ref($self) . "->set_protocols(\\\@protocols)" unless scalar(@{$self->get_protocols()});
  my $success = 1;
  $sdrf_experiment = $sdrf_experiment->clone(); # Don't actually change the SDRF that was passed in
  # Protocols
  #   Get all the protocols from the sdrf_experiment and make sure they exist in the idf
  my @sdrf_protocols;

  foreach my $experiment_prop (@{$self->get_idf_experiment()->get_properties()}) {
    if ($experiment_prop->get_termsource()) {
      my ($full_termsource) = grep { $_->get_db()->get_name() eq $experiment_prop->get_termsource()->get_db()->get_name() } @{$self->get_termsources()};
      if (!$full_termsource ) {
        log_error "Can't find the term source definition in the IDF for " . $experiment_prop->get_termsource()->get_db()->get_name() . " as it applies to " . $experiment_prop->get_name() . ".", "error";
        return 0;
        }
    }
  }

  foreach my $applied_protocol_slots (@{$sdrf_experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      my @matching_protocols = grep { $_->equals($applied_protocol->get_protocol()) } @sdrf_protocols;
      if (!scalar(@matching_protocols)) {
        push @sdrf_protocols, $applied_protocol->get_protocol();
      }
    }
  }
  my @undefined_protocols;
  foreach my $sdrf_protocol (@sdrf_protocols) {
    next if $sdrf_protocol->get_name() eq "->"; # TODO: Handle -> protocols
    my ($idf_protocol) = grep { $_->get_name() eq $sdrf_protocol->get_name() } @{$self->get_protocols()};
    if (!$idf_protocol) {
      push @undefined_protocols, $sdrf_protocol;
    }
  }
  if (scalar(@undefined_protocols)) {
    log_error "The following protocol(s) are referred to in the SDRF but not defined in the IDF!\n  '" . join("', '", map { $_->get_name() } @undefined_protocols) . "'.";
    $success = 0;
  }
  # Parameters
  #   Make sure all the protocol parameters in the IDF exist in the SDRF and vice versa
  #   Collect all of the parameters (by protocol) used in the SDRF from Protocol Attributes, Data, and Data Attributes
  my %named_fields;
  foreach my $applied_protocol_slots (@{$sdrf_experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      my $protocol = $applied_protocol->get_protocol();
      my $protocol_name = $protocol->get_name();
      $named_fields{$protocol_name} = [] unless defined($named_fields{$protocol_name});
      foreach my $protocol_attribute (@{$protocol->get_attributes()}) {
        if (defined($protocol_attribute->get_name()) && length($protocol_attribute->get_name())) {
          push @{$named_fields{$protocol_name}}, $protocol_attribute->get_name();
        }
      }
      foreach my $datum (@{$applied_protocol->get_input_data()}) {
        if (defined($datum->get_name()) && length($datum->get_name())) {
          push @{$named_fields{$protocol_name}}, $datum->get_name();
        }
        foreach my $datum_attribute (@{$datum->get_attributes()}) {
          if (defined($datum_attribute->get_name()) && length($datum_attribute->get_name())) {
            push @{$named_fields{$protocol_name}}, $datum_attribute->get_name();
          }
        }
      }
    }
  }
  foreach my $idf_protocol (@{$self->get_protocols()}) {
    my ($parameters) = grep { $_->get_heading() =~ m/^\s*Protocol Parameters?\s*$/ } @{$idf_protocol->get_attributes()};
    my @idf_params; @idf_params = split /;/, $parameters->get_value() if (defined($parameters));
    for (my $i = 0; $i < scalar(@idf_params); $i++) {
      $idf_params[$i] =~ s/^\s*|\s*$//g;
    }
    my @sdrf_params = defined($named_fields{$idf_protocol->get_name()}) ? @{$named_fields{$idf_protocol->get_name()}} : ();
    # Make sure all IDF params are in the SDRF
    foreach my $idf_param (@idf_params) {
      my @matching_param = grep { $_ eq $idf_param } @sdrf_params;
      if (!scalar(@matching_param)) {
        log_error "Unable to find the '$idf_param' field in the SDRF even though it is defined in the IDF.";
        $success = 0;
      }
    }
  }
  # Term sources
  #   Collect term source DBXrefs from Protocols, Attributes, Datas
  my @term_source_dbs;
  foreach my $applied_protocol_slots (@{$sdrf_experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      if ($applied_protocol->get_protocol()) {
        if ($applied_protocol->get_protocol()->get_termsource() && $applied_protocol->get_protocol()->get_termsource()->get_db()) {
          push @term_source_dbs, $applied_protocol->get_protocol()->get_termsource()->get_db();
        }
        foreach my $attribute (@{$applied_protocol->get_protocol->get_attributes()}) {
          if ($attribute->get_termsource() && $attribute->get_termsource()->get_db()) {
            push @term_source_dbs, $attribute->get_termsource()->get_db();
          }
        }
      }
      foreach my $datum (@{$applied_protocol->get_input_data()}, @{$applied_protocol->get_output_data()}) {
        if ($datum->get_termsource() && $datum->get_termsource()->get_db()) {
          push @term_source_dbs, $datum->get_termsource()->get_db();
        }
        foreach my $attribute (@{$datum->get_attributes()}) {
          if ($attribute->get_termsource() && $attribute->get_termsource()->get_db()) {
            push @term_source_dbs, $attribute->get_termsource()->get_db();
          }
        }
      }
    }
  }
  # Filter to unique DBs
  { my @tmp = @term_source_dbs; @term_source_dbs = (); foreach my $db (@tmp) { if (!scalar(grep { $_->equals($db) } @term_source_dbs)) { push @term_source_dbs, $db; } } }

  my @sdrf_term_sources;
  my @idf_term_sources = map { $_->get_db() } @{$self->get_termsources()};
  foreach my $term_source (@term_source_dbs) {
    my @matching_term_sources = grep { $_->equals($term_source) } @sdrf_term_sources;
    if (!scalar(@matching_term_sources)) {
      push @sdrf_term_sources, $term_source;
    }
  }
  my @undefined_term_sources;
  foreach my $sdrf_term_source (@sdrf_term_sources) {
    if (!scalar(grep { $_->get_name() eq $sdrf_term_source->get_name() } @idf_term_sources)) {
      push @undefined_term_sources, $sdrf_term_source;
    }
  }
  if (scalar(@undefined_term_sources)) {
    log_error "The following term source(s) are referred to in the SDRF but not defined in the IDF!\n  '" . join("', '", map { $_->get_name() } @undefined_term_sources) . "'.";
    $success = 0;
  }

  return $success;
}

1;
