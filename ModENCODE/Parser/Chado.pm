package ModENCODE::Parser::Chado;
=pod

=head1 NAME

ModENCODE::Parser::Chado - Class for generating L<ModENCODE::Chado|index>
objects from a PostgreSQL Chado database.

=head1 SYNOPSIS

This parser can be used to create new L<ModENCODE::Chado|index> objects from a
database. It can do this for a whole L<ModENCODE::Chado::Experiment> object,
which means that you can generate ChadoXML from an
L<Experiment|ModENCODE::Chado::Experiment> object, load it into a database using
L<stag-storenode.pl>, and then pull in back into an
L<Experiment|ModENCODE::Chado::Experiment> object that (should) contain all of
the information in the original object.

This parser is also used by various parts of the validation pipeline for
fetching existing objects from Chado databases when there are referenced in a
BIR-TAB IDF/SDRF. For instances, the L<ModENCODE::Validator::Data::dbEST_acc>
validator initially tries to verify (and fetch EST information) from Chado
databases before falling back to GenBank. To do so, it uses the
L</get_feature_by_genbank_id($genbank_id)> function, which in turn calls the
L</get_feature($feature_id)> function to generate the actual
L<Feature|ModENCODE::Chado::Feature> object.

There are functions for fetching every type of L<ModENCODE::Chado|index> object,
generally of the form C<get_objecttype($object_id)> listed under L</FUNCTIONS>.
There are also several experimental functions that attempt to regenerate a
BIR-TAB document, these are L</get_denormalized_protocol_slots()>,
L</get_normalized_protocol_slots()>, L</get_tsv_columns()>, and
L</get_tsv($columns)>.

=head1 USAGE

Each instance of C<ModENCODE::Parser::Chado> must have an associated database
handle. This should be set before the first call that requires a database
connection. You can either do this during construction:

  my $parser = new ModENCODE::Chado::Parser({
    'host' => 'dbhost',
    'port' => 5432,
    'dbname' => 'chadodb',
    'username' => 'db_user',
    'password' => 'db_passwd'
  });

or after construction but before any calls that require a database connection:

  my $parser = new ModENCODE::Chado::Parser();
  $parser->set_dbname('chadodb');

Note that all arguments are optional except for the C<dbname>.

Once a C<ModENCODE::Chado::Parser> object has been created, you can use it to
pull out L<ModENCODE::Chado|index> objects that you have a database ID (like
C<feature.feature_id>) for using the various C<get_objecttype($object_id)>
L<functions|/FUNCTIONS>. You can also get L<Feature|ModENCODE::Chado::Feature>
IDs by calling L</get_feature_id_by_name_and_type($name, $type, $allow_isa)> or
actual L<Feature|ModENCODE::Chado::Feature> objects by calling
L</get_feature_by_genbank_id($genbank_id)>.

B<NOTE:> Before you start making any calls to L</get_experiment()>, or to any of
the experimental BIR-TAB functions, you must call
L</load_experiment($experiment_id)>. This one case doesn't match the other
functions for fetching objects, because so many experiment-specific things are
cached in the parser. To improve performance, an
L<Experiment|ModENCODE::Chado::Experiment> must be loaded all in one go, and
future calls to L</get_experiment()> will always return that preloaded object.

When the C<ModENCODE::Chado::Parser> object is destroyed or goes out of scope,
the database handle is closed.

=head1 FUNCTIONS

=head2 Functions for Fetching L<ModENCODE::Chado|index> Objects

=over

=item get_available_experiments()

Return an arrayref of hashes of the form C<{ 'experiment_id' => $experiment_id,
'uniquename' => $uniquename, 'description' => $description }>. Meant to be used
to print a list of available experiments to fetch.

=item load_experiment($experiment_id)

Load the L<Experiment|ModENCODE::Chado::Experiment> object referenced by
C<$experiment_id> from the database and cache it in this parser. It can then be
retrieved using L</get_experiment()> as an
L<Experiment|ModENCODE::Chado::Experiment> object, or as BIR-TAB format by using
L</get_tsv($columns)>.

=item get_experiment()

Return the L<Experiment|ModENCODE::Chado::Experiment> object currently loaded in
this parser from L</load_experiment($experiment_id)>. Prints an error if
L</load_experiment($experiment_id)> hasn't yet been called.

=item get_applied_protocol($applied_protocol_id)

Return a L<ModENCODE::Chado::AppliedProtocol> object for an applied protocol in
a Chado database. (Requires that the BIR-TAB extension is installed.) Recurses
to fetch any other objects associated with the
L<AppliedProtocol|ModENCODE::Chado::AppliedProtocol>.

=item get_protocol($protocol_id)

Return a L<ModENCODE::Chado::Protocol> object for a protocol in a Chado
database. (Requires that the BIR-TAB extension is installed.) Recurses to fetch
any other objects associated with the L<Protocol|ModENCODE::Chado::Protocol>.

=item get_datum($datum_id)

Return a L<ModENCODE::Chado::Data> object for a datum in a Chado database.
(Requires that the BIR-TAB extension is installed.) Recurses to fetch any other
objects associated with the L<Data|ModENCODE::Chado::Data>.

=item get_term_source($term source_id)

Return a L<ModENCODE::Chado::DBXref> object for a term source in a Chado
database. Recurses to fetch any other objects associated with the
L<DBXref|ModENCODE::Chado::DBXref>.

=item get_feature($feature_id)

Return a L<ModENCODE::Chado::Feature> object for a feature in a Chado database.
Recurses to fetch any other objects associated with the
L<Feature|ModENCODE::Chado::Feature>.

=item get_feature_location($feature location_id)

Return a L<ModENCODE::Chado::FeatureLoc> object for a feature location in a
Chado database. Recurses to fetch any other objects associated with the
L<FeatureLoc|ModENCODE::Chado::FeatureLoc>.

=item get_feature_relationship($feature relationship_id)

Return a L<ModENCODE::Chado::FeatureRelationship> object for a feature
relationship in a Chado database. Recurses to fetch any other objects associated
with the L<FeatureRelationship|ModENCODE::Chado::FeatureRelationship>.

=item get_analysis_feature($analysis feature_id)

Return a L<ModENCODE::Chado::AnalysisFeature> object for an analysis feature in
a Chado database. Recurses to fetch any other objects associated with the
L<AnalysisFeature|ModENCODE::Chado::AnalysisFeature>.

=item get_analysis($analysis_id)

Return a L<ModENCODE::Chado::Analysis> object for an analysis in a Chado
database. Recurses to fetch any other objects associated with the
L<Analysis|ModENCODE::Chado::Analysis>.

=item get_organism($organism_id)

Return a L<ModENCODE::Chado::Organism> object for an organism in a Chado
database. Recurses to fetch any other objects associated with the
L<Organism|ModENCODE::Chado::Organism>.

=item get_wiggle_data($wiggle data_id)

Return a L<ModENCODE::Chado::Wiggle_Data> object for a wiggle data in a Chado
database. (Requires that the BIR-TAB extension is installed.) Recurses to fetch
any other objects associated with the
L<Wiggle_Data|ModENCODE::Chado::Wiggle_Data>.

=item get_db($db_id)

Return a L<ModENCODE::Chado::DB> object for a database in a Chado database.
Recurses to fetch any other objects associated with the
L<DB|ModENCODE::Chado::DB>.

=item get_type($type_id)

Return a L<ModENCODE::Chado::CVTerm> object for a controlled vocabulary term in
a Chado database. Recurses to fetch any other objects associated with the
L<CVTerm|ModENCODE::Chado::CVTerm>.

=item get_attribute($attribute_id)

Return a L<ModENCODE::Chado::Attribute> object for an attribute in a Chado
database. (Requires that the BIR-TAB extension is installed.) Recurses to fetch
any other objects associated with the L<Attribute|ModENCODE::Chado::Attribute>.

=item get_feature_by_genbank_id($genbank_id)

Returns a L<Feature|ModENCODE::Chado::Feature> object for a feature that has an
entry in the Chado C<dbxref> table with a C<db.name> of 'GB' and an C<accession>
of C<$genbank_id>.  It also currently requires that the organism is I<Drosophila
melanogaster>.

=item get_feature_id_by_name_and_type($name, $type, $allow_isa)

Given a C<$name> string, a L<CVTerm|ModENCODE::Chado::CVTerm> type, and a
boolean C<$allow_isa>, returns a Chado C<feature_id> for a feature with a Chado
C<feature.name> equal to C<$name>, whose type is either equal to C<$type> or is
in the same controlled vocabulary and is a child of the given C<$type> by
L<ModENCODE::Validator::CVHandler/term_isa($cvname, $term, $ancestor)>.

=back

=head2 Experimental Functions for Generating BIR-TAB

=over

=item get_normalized_protocol_slots()

B<EXPERIMENTAL>

Returns an arrayref of arrays. The outer array has an entry for each round of
protocols (the C<Protocol REF> columns from an SDRF). The inner arrays have an
entry for each L<AppliedProtocol|ModENCODE::Chado::AppliedProtocol> (one per row
in an SDRF, ignoring any merging or splitting of data). See
L<ModENCODE::Chado::Experiment/Applied Protocols> for more information.

=item get_denormalized_protocol_slots()

B<EXPERIMENTAL>

Returns an arrayref of arrays. The outer array has an entry for each round of
protocols (the C<Protocol REF> columns from an SDRF). The inner arrays have an
entry for each L<AppliedProtocol|ModENCODE::Chado::AppliedProtocol>. Unlike
L</get_normalized_protocol_slots()>, this function first reduces the
L<AppliedProtocols|ModENCODE::Chado::AppliedProtocol> down to the minimum number
to represent the information. For example, if four SDRF rows are used to define
four different inputs to the same protocol, but the output for all for rows is
the same, then there only need be one applied protocol. (In contrast, if there
are four different inputs and four different outputs, then there are four
applied protocols.) See L<ModENCODE::Chado::Experiment/Applied Protocols> for more
information.

=item get_tsv_columns()

B<EXPERIMENTAL>

Returns an arrayref of arrays that effectively represents a spreadsheet; the
outer array indices are the columns and the inner array indices are the rows.
The structure represents a flattened BIR-TAB document. Use L</get_tsv($columns)> to
retrieve the structure formatted as a tab-separated BIR-TAB document.

=item get_tsv($columns)

B<EXPERIMENTAL>

Return a properly tab-separated BIR-TAB document representing the
L<Experiment|ModENCODE::Chado::Experiment> spreadsheet in C<$columns>. If
C<$columns> is not specified, it is generated from the currently loaded
experiment by L</get_tsv_columns()>. Printing the results of this function to a
file should generate a BIR-TAB document that is equivalent to (or a superset of)
the one that has was converted to ChadoXML, loaded into a Chado database, and
then parsed using this parser.

=back

=head1 SEE ALSO

L<Class::Std>, L<DBI>, L<ModENCODE::Chado::Analysis>,
L<ModENCODE::Chado::AnalysisFeature>, L<ModENCODE::Chado::AppliedProtocol>,
L<ModENCODE::Chado::Attribute>, L<ModENCODE::Chado::CV>,
L<ModENCODE::Chado::CVTerm>, L<ModENCODE::Chado::DB>,
L<ModENCODE::Chado::DBXref>, L<ModENCODE::Chado::Data>,
L<ModENCODE::Chado::Experiment>, L<ModENCODE::Chado::ExperimentProp>,
L<ModENCODE::Chado::Feature>, L<ModENCODE::Chado::FeatureLoc>,
L<ModENCODE::Chado::FeatureRelationship>, L<ModENCODE::Chado::Organism>,
L<ModENCODE::Chado::Protocol>, L<ModENCODE::Chado::Wiggle_Data>,
L<ModENCODE::Chado::XMLWriter>, L<stag-storenode.pl>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use Class::Std;
use Data::Dumper;

use DBI;
use ModENCODE::Chado::Experiment;
use ModENCODE::Chado::ExperimentProp;
use ModENCODE::Chado::AppliedProtocol;
use ModENCODE::Chado::Protocol;
use ModENCODE::Chado::Data;
use ModENCODE::Chado::DB;
use ModENCODE::Chado::DBXref;
use ModENCODE::Chado::CV;
use ModENCODE::Chado::CVTerm;
use ModENCODE::Chado::Attribute;
use ModENCODE::Chado::ProtocolAttribute;
use ModENCODE::Chado::DatumAttribute;
use ModENCODE::Chado::Feature;
use ModENCODE::Chado::FeatureLoc;
use ModENCODE::Chado::AnalysisFeature;
use ModENCODE::Chado::FeatureRelationship;
use ModENCODE::Chado::Organism;
use ModENCODE::Chado::Wiggle_Data;
use ModENCODE::ErrorHandler qw(log_error);

my %dbh                 :ATTR(                                :default<undef> );
my %host                :ATTR( :name<host>,                   :default<undef> );
my %port                :ATTR( :name<port>,                   :default<undef> );
my %dbname              :ATTR( :name<dbname>,                 :default<undef> );
my %username            :ATTR( :name<username>,               :default<''> );
my %password            :ATTR( :name<password>,               :default<''> );
my %protocol_slots      :ATTR(                                :default<[]> );
my %experiment          :ATTR(                                :default<undef> );
my %prepared_queries    :ATTR(                                :default<{}> );
my %no_relationships    :ATTR( :name<no_relationships>,       :default<0> );
my %child_relationships :ATTR( :name<child_relationships>,    :default<0> );
my %schema              :ATTR( :get<schema>,                  :default<'public'> );

sub new {
  my $self = Class::Std::new(@_);

  if (defined($self->get_dbname())) {
    # Try to pre-connect to the database; suppress warnings
    # On failure, return undef
    if (!$self->get_dbh(1)) {
      log_error "Failed to initialize ModENCODE::Chado::Parser for " . $self->get_dbname . ".", "warning", ">";
      my $errstr = $DBI::errstr;
      chomp($errstr);
      log_error $errstr, "warning";
      log_error "", "warning", "<";
      return undef;
    }
  }

  return $self;
}

sub DEMOLISH {
  my ($self) = @_;
  if ($dbh{ident $self}) {
    foreach my $query (values(%{$prepared_queries{ident $self}})) {
      $query->finish();
    }
    $dbh{ident $self}->disconnect();
  }
}

sub get_available_experiments {
  my ($self) = @_;
  my $sth = $self->get_prepared_query("SELECT experiment_id, uniquename, description FROM experiment");
  $sth->execute();
  my @experiments;
  while (my $row = $sth->fetchrow_hashref()) {
    map { $row->{$_} = xml_unescape($row->{$_}) } keys(%$row);
    push @experiments, $row;
  }
  return \@experiments;
}

sub get_experiment {
  my ($self) = @_;
  if (!scalar(@{$protocol_slots{ident $self}})) {
    log_error "Protocol slots are empty; perhaps you need to call load_experiment(\$experiment_id) first?";
  }
  if (!defined($experiment{ident $self})) {
    log_error "Experiment is empty; perhaps you need to call load_experiment(\$experiment_id) first?";
  }
  return $experiment{ident $self};
}

sub load_experiment {
  my ($self, $experiment_id) = @_;

  my @protocol_slots;
  # Get the first (leftmost) set of applied protocols used in this experiment
  my $first_proto_sth = $self->get_prepared_query("SELECT first_applied_protocol_id FROM experiment_applied_protocol WHERE experiment_id = ?");
  $first_proto_sth->execute($experiment_id);
  my @applied_protocols;
  while (my ($app_proto_id) = $first_proto_sth->fetchrow_array()) {
    my $app_proto = $self->get_applied_protocol($app_proto_id);
    push @applied_protocols, $app_proto;
  }
  @applied_protocols = map { { 'applied_protocol' => $_, 'previous_applied_protocol_id' => [] } } @applied_protocols;
  $protocol_slots[0] = \@applied_protocols;

  # Follow the linked list of applied_protocol->data->applied_protocol and
  # fill in the rest of the protocol slots
  my $get_next_applied_protocols_sth = $self->get_prepared_query("SELECT apd.applied_protocol_id FROM applied_protocol_data apd WHERE apd.data_id = ? AND apd.direction = 'input'");
  my %next_applied_protocols;
  do { # while (scalar(values(%next_applied_protocols)))
    my @applied_protocol_data;
    # For each applied_protocol in the current column, get the output data
    foreach my $applied_protocol (@{$protocol_slots[scalar(@protocol_slots)-1]}) {
      foreach my $datum ($applied_protocol->{'applied_protocol'}->get_output_data(1)) {
        push @applied_protocol_data, { 
          'from_applied_protocol' => $applied_protocol->{'applied_protocol'}->get_id, 
          'datum' => $datum
        };
      }
    }
    # For each piece of output data collected, fetch the applied protocols
    # that use it as input data
    my @next_applied_protocol_ids;
    undef(%next_applied_protocols);
    foreach my $datum (@applied_protocol_data) {
      $get_next_applied_protocols_sth->execute($datum->{'datum'}->get_id());
      while (my ($applied_protocol_id) = $get_next_applied_protocols_sth->fetchrow_array()) {
        if (!scalar(grep { $_ == $applied_protocol_id } @next_applied_protocol_ids)) {
          push @next_applied_protocol_ids, $applied_protocol_id;
          $next_applied_protocols{$applied_protocol_id} = {
            'applied_protocol' => $self->get_applied_protocol($applied_protocol_id),
            'previous_applied_protocol_id' => [ $datum->{'from_applied_protocol'} ],
          };
        } else {
          push @{$next_applied_protocols{$applied_protocol_id}->{'previous_applied_protocol_id'}}, $datum->{'from_applied_protocol'};
        }
      }
    }
    # If there were any applied_protocols collected, then push them into the
    # protocol slots
    if (scalar(values(%next_applied_protocols))) {
      my @copy_of_next_applied_protocols = values(%next_applied_protocols);
      push @protocol_slots, \@copy_of_next_applied_protocols;
    }
  } while (scalar(values(%next_applied_protocols)));
  $protocol_slots{ident $self} = \@protocol_slots;

  my $experiment_sth = $self->get_prepared_query("SELECT experiment_id, uniquename, description FROM experiment WHERE experiment_id = ?");
  $experiment_sth->execute($experiment_id);
  my $row = $experiment_sth->fetchrow_hashref();
  map { $row->{$_} = xml_unescape($row->{$_}) } keys(%$row);
  $experiment{ident $self} = new ModENCODE::Chado::Experiment({
      'description' => $row->{'description'},
      'uniquename' => $row->{'uniquename'},
      'applied_protocol_slots' => $self->get_normalized_protocol_slots(),
    });
  my $experiment_prop_sth = $self->get_prepared_query("SELECT name, type_id, dbxref_id, value, rank FROM experiment_prop WHERE experiment_id = ?");
  $experiment_prop_sth->execute($experiment_id);
  while (my $row = $experiment_prop_sth->fetchrow_hashref()) {
    map { $row->{$_} = xml_unescape($row->{$_}) } keys(%$row);
    my $property = new ModENCODE::Chado::ExperimentProp({
        'experiment' => $experiment{ident $self},
        'name' => $row->{'name'},
        'value' => $row->{'value'},
        'rank' => $row->{'rank'},
      });
    my $termsource = $self->get_termsource($row->{'dbxref_id'});
    $property->get_object->set_termsource($termsource) if $termsource;
    my $type = $self->get_type($row->{'type_id'});
    $property->get_object->set_type($type) if $type;
    $experiment{ident $self}->add_property($property);
  }
}

sub get_applied_protocol {
  my ($self, $applied_protocol_id) = @_;
  my $sth = $self->get_prepared_query("SELECT protocol_id FROM applied_protocol WHERE applied_protocol_id = ?");
  $sth->execute($applied_protocol_id);
  my ($protocol_id) = $sth->fetchrow_array();
  my $protocol = $self->get_protocol($protocol_id);
  $sth = $self->get_prepared_query("SELECT data_id, direction FROM applied_protocol_data WHERE applied_protocol_id = ?");
  $sth->execute($applied_protocol_id);
  my $applied_protocol = new ModENCODE::Chado::AppliedProtocol({ 
#      'id' => $applied_protocol_id,
      'protocol' => $protocol,
    });
  while (my $row = $sth->fetchrow_hashref()) {
    map { $row->{$_} = xml_unescape($row->{$_}) } keys(%$row);
    if ($row->{'direction'} =~ 'input') {
      $applied_protocol->add_input_datum($self->get_datum($row->{'data_id'}));
    } else {
      $applied_protocol->add_output_datum($self->get_datum($row->{'data_id'}));
    }
  }
  return $applied_protocol;
}

sub get_protocol {
  my ($self, $protocol_id) = @_;
  my $sth = $self->get_prepared_query("SELECT name, version, description, dbxref_id FROM protocol WHERE protocol_id = ?");
  $sth->execute($protocol_id);
  my $row = $sth->fetchrow_hashref();
  map { $row->{$_} = xml_unescape($row->{$_}) } keys(%$row);
  my $termsource = $self->get_termsource($row->{'dbxref_id'});
  my $protocol = new ModENCODE::Chado::Protocol({ 
#      'id' => $protocol_id,
      'name' => $row->{'name'},
      'version' => $row->{'version'},
      'description' => $row->{'description'},
      'termsource' => $termsource,
    });
  $sth = $self->get_prepared_query("SELECT attribute_id FROM protocol_attribute WHERE protocol_id = ?");
  $sth->execute($protocol_id);
  while (my ($attr_id) = $sth->fetchrow_array()) {
    $protocol->get_object->add_attribute($self->get_attribute($attr_id, $protocol));
  }
  return $protocol;
}

sub get_datum {
  my ($self, $datum_id) = @_;
  my $sth = $self->get_prepared_query("SELECT name, heading, value, dbxref_id, type_id FROM data WHERE data_id = ?");
  $sth->execute($datum_id);
  my $row = $sth->fetchrow_hashref();
  map { $row->{$_} = xml_unescape($row->{$_}) } keys(%$row);
  my $termsource = $self->get_termsource($row->{'dbxref_id'});
  my $type = $self->get_type($row->{'type_id'});

  my $datum = new ModENCODE::Chado::Data({ 
#      'id' => $datum_id,
      'name' => $row->{'name'},
      'heading' => $row->{'heading'},
      'value' => $row->{'value'},
      'termsource' => $termsource,
      'type' => $type,
    });

  $sth = $self->get_prepared_query("SELECT wiggle_data_id FROM data_wiggle_data WHERE data_id = ?");
  $sth->execute($datum_id);
  while (my ($wiggle_data_id) = $sth->fetchrow_array()) {
    $datum->get_object->add_wiggle_data($self->get_wiggle_data($wiggle_data_id, $datum));
  }

  $sth = $self->get_prepared_query("SELECT feature_id FROM data_feature WHERE data_id = ?");
  $sth->execute($datum_id);
  while (my ($feature_id) = $sth->fetchrow_array()) {
    $datum->get_object->add_feature($self->get_feature($feature_id));
  }

  $sth = $self->get_prepared_query("SELECT organism_id FROM data_organism WHERE data_id = ?");
  $sth->execute($datum_id);
  while (my ($organism_id) = $sth->fetchrow_array()) {
    $datum->get_object->add_organism($self->get_organism($organism_id));
  }

  $sth = $self->get_prepared_query("SELECT attribute_id FROM data_attribute WHERE data_id = ?");
  $sth->execute($datum_id);
  while (my ($attr_id) = $sth->fetchrow_array()) {
    $datum->get_object->add_attribute($self->get_attribute($attr_id, $datum));
  }
  return $datum;
}

sub get_dbxref{
  # Alias
  get_termsource(@_);
}

sub get_termsource {
  my ($self, $dbxref_id) = @_;
  return undef unless($dbxref_id);
  my $sth = $self->get_prepared_query("SELECT accession, version, db_id FROM dbxref WHERE dbxref_id = ?");
  $sth->execute($dbxref_id);
  my $row = $sth->fetchrow_hashref();
  map { $row->{$_} = xml_unescape($row->{$_}) } keys(%$row);
  $row->{'accession'} =~ s/.*://; # Get rid of flybase DB:acc style accessions
  my $dbxref = new ModENCODE::Chado::DBXref({
      'accession' => $row->{'accession'},
      'version' => $row->{'version'},
      'db' => $self->get_db($row->{'db_id'}),
    });
  return $dbxref;
}

sub get_feature {
  my ($self, $feature_id) = @_;
  return undef unless($feature_id);
  my $sth = $self->get_prepared_query("SELECT 
    f.name, f.uniquename, f.residues, f.seqlen, f.organism_id, f.type_id, 
    f.timeaccessioned, f.timelastmodified, f.is_analysis,
    f.dbxref_id as primary_dbxref_id
    FROM feature f 
    WHERE f.feature_id = ?");
  $sth->execute($feature_id);
  my $row = $sth->fetchrow_hashref();

  my @analysisfeatures;
  $sth = $self->get_prepared_query("SELECT analysis_id FROM analysisfeature WHERE feature_id = ?");
  $sth->execute($feature_id);
  while (my $af_row = $sth->fetchrow_hashref()) {
    push @analysisfeatures, $af_row->{'analysisfeature_id'};
  }

  my @relationships;
  unless ($self->get_no_relationships()) {
    $sth = $self->get_prepared_query("SELECT feature_relationship_id FROM feature_relationship WHERE object_id = ? OR subject_id = ?");
    $sth->execute($feature_id, $feature_id);
    while (my $fr_row = $sth->fetchrow_hashref()) {
      push @relationships, $fr_row->{'feature_relationship_id'};
    }
  } elsif ($self->get_child_relationships()) {
    $sth = $self->get_prepared_query("SELECT fr.feature_relationship_id FROM feature_relationship fr INNER JOIN cvterm cvt ON fr.type_id = cvt.cvterm_id WHERE fr.object_id = ? AND (cvt.name = 'part_of' OR cvt.name = 'part of' OR cvt.name = 'partof')");
    $sth->execute($feature_id);
    while (my $fr_row = $sth->fetchrow_hashref()) {
      push @relationships, $fr_row->{'feature_relationship_id'};
    }
  }

  my @dbxrefs;
  $sth = $self->get_prepared_query("SELECT dbxref_id FROM feature_dbxref WHERE feature_id = ?");
  $sth->execute($feature_id);
  while (my $dbx_row = $sth->fetchrow_hashref()) {
    push @dbxrefs, $dbx_row->{'dbxref_id'};
  }

  my @locations;
  $sth = $self->get_prepared_query("SELECT featureloc_id FROM featureloc WHERE feature_id = ?");
  $sth->execute($feature_id);
  while (my $dbx_row = $sth->fetchrow_hashref()) {
    push @locations, $dbx_row->{'featureloc_id'};
  }

  map { $row->{$_} = xml_unescape($row->{$_}) } keys(%$row);
  my $feature = new ModENCODE::Chado::Feature({
#      'id' => $feature_id,
      'name' => $row->{'name'},
      'uniquename' => $row->{'uniquename'},
      'residues' => $row->{'residues'},
      'seqlen' => $row->{'seqlen'},
      'timeaccessioned' => $row->{'timeaccessioned'},
      'timelastmodified' => $row->{'timelastmodified'},
      'is_analysis' => $row->{'is_analysis'},
      'type' => $self->get_type($row->{'type_id'}),
      'organism' => $self->get_organism($row->{'organism_id'}),
      'primary_dbxref' => $self->get_termsource($row->{'primary_dbxref_id'}),
    });

  foreach my $analysisfeature_id (@analysisfeatures) {
    $feature->get_object->add_analysisfeature($self->get_analysisfeature($analysisfeature_id));
  }
  foreach my $dbxref_id (@dbxrefs) {
    $feature->get_object->add_dbxref($self->get_termsource($dbxref_id));
  }
  foreach my $location_id (@locations) {
    $feature->get_object->add_location($self->get_featureloc($location_id, $feature));
  }
  foreach my $relationship_id (@relationships) {
    $feature->get_object->add_relationship($self->get_feature_relationship($relationship_id, $feature, $feature_id));
  }
  $feature->get_object->dirty();
  return $feature;
}

sub get_featureloc {
  my ($self, $featureloc_id, $feature) = @_;
  my $sth = $self->get_prepared_query("SELECT fmin, fmax, rank, strand, srcfeature_id FROM featureloc WHERE featureloc_id = ?");
  $sth->execute($featureloc_id);
  my $row = $sth->fetchrow_hashref();
  map { $row->{$_} = xml_unescape($row->{$_}) } keys(%$row);
  my $featureloc = new ModENCODE::Chado::FeatureLoc({
      'fmin' => $row->{'fmin'},
      'fmax' => $row->{'fmax'},
      'rank' => $row->{'rank'},
      'strand' => $row->{'strand'},
      'srcfeature' => $self->get_feature($row->{'srcfeature_id'}) || $feature,
    });
  return $featureloc;
}

sub get_feature_relationship {
  my ($self, $feature_relationship_id, $calling_feature, $calling_feature_id) = @_;
  my $sth = $self->get_prepared_query("SELECT rank, subject_id, object_id, type_id FROM feature_relationship WHERE feature_relationship_id = ?");
  $sth->execute($feature_relationship_id);
  my $row = $sth->fetchrow_hashref();
  map { $row->{$_} = xml_unescape($row->{$_}) } keys(%$row);

  my $subject = undef;
  $subject = $calling_feature if ($calling_feature_id == $row->{'subject_id'});
  $subject ||= $self->get_feature($row->{'subject_id'});

  my $object = undef;
  $object = $calling_feature if ($calling_feature_id == $row->{'object_id'});
  $object ||= $self->get_feature($row->{'object_id'});

  my $feature_relationship = new ModENCODE::Chado::FeatureRelationship({
      'rank' => $row->{'rank'},
      'type' => $self->get_type($row->{'type_id'}),
      'subject' => $subject,
      'object' => $object,
    });
  return $feature_relationship;
}

sub get_analysisfeature {
  my ($self, $analysisfeature_id) = @_;
  my $sth = $self->get_prepared_query("SELECT rawscore, normscore, significance, identity, feature_id, analysis_id FROM analysisfeature WHERE analysisfeature_id = ?");
  $sth->execute($analysisfeature_id);
  my $row = $sth->fetchrow_hashref();
  map { $row->{$_} = xml_unescape($row->{$_}) } keys(%$row);

  my $analysis = $self->get_analysis($row->{'analysis_id'});
  my $feature = $self->get_feature($row->{'feature_id'});

  my $analysisfeature = new ModENCODE::Chado::AnalysisFeature({ 
#      'id' => $analysisfeature_id,
      'rawscore' => $row->{'rawscore'},
      'normscore' => $row->{'normscore'},
      'significance' => $row->{'significance'},
      'identity' => $row->{'identity'},
      'analysis' => $analysis,
      'feature' => $feature,
    });
  return $analysisfeature;
}

sub get_analysis {
  my ($self, $analysis_id) = @_;
  my $sth = $self->get_prepared_query("SELECT name, description, program, programversion, algorithm, sourcename, sourceversion, sourceuri, timeexecuted FROM analysis WHERE analysis_id = ?");
  $sth->execute($analysis_id);
  my $row = $sth->fetchrow_hashref();
  map { $row->{$_} = xml_unescape($row->{$_}) } keys(%$row);

  
  my $analysis = new ModENCODE::Chado::Analysis({ 
#      'id' => $analysis_id,
      'name' => $row->{'name'},
      'description' => $row->{'description'},
      'program' => $row->{'program'},
      'programversion' => $row->{'programversion'},
      'algorithm' => $row->{'algorithm'},
      'sourcename' => $row->{'sourcename'},
      'sourceversion' => $row->{'sourceversion'},
      'sourceuri' => $row->{'sourceuri'},
      'timeexecuted' => $row->{'timeexecuted'},
    });
  return $analysis;
}

sub get_organism {
  my ($self, $organism_id) = @_;
  return undef unless($organism_id);
  my $sth = $self->get_prepared_query("SELECT genus, species FROM organism WHERE organism_id = ?");
  $sth->execute($organism_id);
  my $row = $sth->fetchrow_hashref();
  map { $row->{$_} = xml_unescape($row->{$_}) } keys(%$row);
  my $organism = new ModENCODE::Chado::Organism({
      'genus' => $row->{'genus'},
      'species' => $row->{'species'},
    });
  return $organism;
}

sub get_wiggle_data {
  my ($self, $wiggle_data_id, $datum) = @_;
  return undef unless($wiggle_data_id);
  my $sth = $self->get_prepared_query("SELECT type, name, visibility, color, altColor, priority, autoscale, gridDefault, maxHeightPixels, graphType, viewLimits, yLineMark, yLineOnOff, windowingFunction, smoothingWindow, data FROM wiggle_data WHERE wiggle_data_id = ?");
  $sth->execute($wiggle_data_id);
  my $row = $sth->fetchrow_hashref();
  map { $row->{$_} = xml_unescape($row->{$_}) } keys(%$row);
  my $wiggle_data = new ModENCODE::Chado::Wiggle_Data({
      'datum' => $datum,
      'type' => $row->{'type'},
      'name' => $row->{'name'},
      'visibility' => $row->{'visibility'},
      'color' => $row->{'color'},
      'altColor' => $row->{'altColor'},
      'priority' => $row->{'priority'},
      'autoscale' => $row->{'autoscale'},
      'gridDefault' => $row->{'gridDefault'},
      'maxHeightPixels' => $row->{'maxHeightPixels'},
      'graphType' => $row->{'graphType'},
      'viewLimits' => $row->{'viewLimits'},
      'yLineMark' => $row->{'yLineMark'},
      'yLineOnOff' => $row->{'yLineOnOff'},
      'windowingFunction' => $row->{'windowingFunction'},
      'smoothingWindow' => $row->{'smoothingWindow'},
      'data' => $row->{'data'},
    });
  return $wiggle_data;
}

sub get_db {
  my($self, $db_id) = @_;
  return undef unless ($db_id);
  my $sth = $self->get_prepared_query("SELECT name, url, description FROM db WHERE db_id = ?");
  $sth->execute($db_id);
  my $row = $sth->fetchrow_hashref();
  map { $row->{$_} = xml_unescape($row->{$_}) } keys(%$row);
  my $db = new ModENCODE::Chado::DB({
      'name' => $row->{'name'},
      'url' => $row->{'url'},
      'description' => $row->{'description'},
    });
  return $db;
}

sub get_type {
  my ($self, $cvterm_id) = @_;
  return undef unless($cvterm_id);
  my $sth = $self->get_prepared_query("SELECT cvt.name, cvt.definition, cvt.is_obsolete, cvt.dbxref_id, cv.name as cvname, cv.definition as cvdefinition FROM cvterm cvt INNER JOIN cv ON cvt.cv_id = cv.cv_id WHERE cvterm_id = ?");
  $sth->execute($cvterm_id);
  my $row = $sth->fetchrow_hashref();
  map { $row->{$_} = xml_unescape($row->{$_}) } keys(%$row);

  #XXX: Rename SO:so terms to SO:mRNA
  $row->{'name'} = "mRNA" if $row->{'name'} eq "so";

  my $cvterm = new ModENCODE::Chado::CVTerm({
      'name' => $row->{'name'},
      'definition' => $row->{'definition'},
      'is_obsolete' => $row->{'is_obsolete'},
      'cv' => new ModENCODE::Chado::CV({ 
          'name' => $row->{'cvname'}, 
          'definition' => $row->{'definition'} 
        }),
    });
  my $termsource = $self->get_termsource($row->{'dbxref_id'});
  $cvterm->get_object->set_dbxref($termsource) if $termsource;
  return $cvterm;
}

sub get_attribute {
  my ($self, $attribute_id, $parent) = @_;
  my $sth = $self->get_prepared_query("SELECT name, heading, value, dbxref_id, type_id FROM attribute WHERE attribute_id = ?");
  $sth->execute($attribute_id);
  my $row = $sth->fetchrow_hashref();
  map { $row->{$_} = xml_unescape($row->{$_}) } keys(%$row);
  my $termsource = $self->get_termsource($row->{'dbxref_id'});
  my $type = $self->get_type($row->{'type_id'});

  my $init_args = { 
#    'id' => $attribute_id,
    'name' => $row->{'name'},
    'heading' => $row->{'heading'},
    'value' => $row->{'value'},
    'termsource' => $termsource,
    'type' => $type,
  };
  my $attribute;
  if (ref($parent) eq "ModENCODE::Cache::Protocol") {
    $init_args->{'protocol'} = $parent;
    $attribute = new ModENCODE::Chado::ProtocolAttribute($init_args);
  } elsif (ref($parent) eq "ModENCODE::Cache::Data") {
    $init_args->{'datum'} = $parent;
    $attribute = new ModENCODE::Chado::DatumAttribute($init_args);
  } else {
    print STDERR "What's a " . ref($parent) . "\n";
    $attribute = new ModENCODE::Chado::Attribute($init_args);
  }

  $sth = $self->get_prepared_query("SELECT organism_id FROM attribute_organism WHERE attribute_id = ?");
  $sth->execute($attribute_id);
  while (my ($organism_id) = $sth->fetchrow_array()) {
    $attribute->get_object->add_organism($self->get_organism($organism_id));
  }

  return $attribute;
}

sub get_feature_id_by_name_and_type {
  # Helper method for ModENCODE::Validator::Data::SO_transcript and possibly others
  my ($self, $feature_name, $type, $allow_isa) = @_;

  $allow_isa ||= 0;

  my $sth = $self->get_prepared_query("SELECT 
    f.feature_id, cvt.name as cvterm, cv.name as cv 
    FROM feature f 
    INNER JOIN cvterm cvt ON f.type_id = cvt.cvterm_id 
    INNER JOIN cv ON cvt.cv_id = cv.cv_id 
    WHERE 
    (f.name = ?)
    AND organism_id = 1");
  $sth->execute($feature_name);
  my @found_feature_ids;
  while (my $row = $sth->fetchrow_hashref()) {
    if (
      (
        (!$allow_isa && $row->{'cvterm'} eq $type->get_name())
        ||
        ($allow_isa && ModENCODE::Config::get_cvhandler()->term_isa(
            $row->{'cv'},
            $row->{'cvterm'},
            $type->get_name()),
        )
      )
      && ModENCODE::Config::get_cvhandler()->cvname_has_synonym($row->{'cv'}, $type->get_cv(1)->get_name())
    ) {
      push @found_feature_ids, $row->{'feature_id'};
    }
  }
  if (!scalar(@found_feature_ids)) {
    my $sth = $self->get_prepared_query("SELECT 
      f.feature_id, cvt.name as cvterm, cv.name as cv 
      FROM feature f 
      INNER JOIN cvterm cvt ON f.type_id = cvt.cvterm_id 
      INNER JOIN cv ON cvt.cv_id = cv.cv_id 
      INNER JOIN feature_dbxref fdbx ON fdbx.feature_id = f.feature_id
      INNER JOIN dbxref dbx ON fdbx.dbxref_id = dbx.dbxref_id
      WHERE 
      (dbx.accession = ?)
      AND organism_id = 1");
    $sth->execute($feature_name);
    while (my $row = $sth->fetchrow_hashref()) {
      if (
        (
          (!$allow_isa && $row->{'cvterm'} eq $type->get_name())
          ||
          ($allow_isa && ModENCODE::Config::get_cvhandler()->term_isa(
              $row->{'cv'},
              $row->{'cvterm'},
              $type->get_name()),
          )
        )
        && ModENCODE::Config::get_cvhandler()->cvname_has_synonym($row->{'cv'}, $type->get_cv(1)->get_name())
      ) {
        push @found_feature_ids, $row->{'feature_id'};
      }
    }
  }
  if (scalar(@found_feature_ids) == 0) {
    return undef;
  } elsif (scalar(@found_feature_ids) > 1) {
    log_error "Found more than one feature '$feature_name' with type " . $type->to_string() . ".", "warning";
    log_error join(", ", @found_feature_ids), "notice";
  }
  return $found_feature_ids[0];
}

sub get_feature_by_organisms_and_name {
  my ($self, $genus, $species, $accession) = @_;
  my $sth = $self->get_prepared_query("
    SELECT f.feature_id FROM feature f
    INNER JOIN organism o ON f.organism_id = o.organism_id
    WHERE o.genus = ANY(?) AND o.species = ANY(?) AND f.name = ?
    ");
  $sth->execute($genus, $species, $accession);
  my ($feature_id) = $sth->fetchrow_array();
  return unless $feature_id;
  return $self->get_feature($feature_id);
}

sub get_feature_by_organisms_and_uniquename {
  my ($self, $genus, $species, $accession) = @_;
  my $sth = $self->get_prepared_query("
    SELECT f.feature_id FROM feature f
    INNER JOIN organism o ON f.organism_id = o.organism_id
    WHERE o.genus = ANY(?) AND o.species = ANY(?) AND f.uniquename = ?
    ");
  $sth->execute($genus, $species, $accession);
  my ($feature_id) = $sth->fetchrow_array();
  return unless $feature_id;
  return $self->get_feature($feature_id);
}


sub get_feature_by_dbs_and_accession {
  my ($self, $db, $accession) = @_;
  my $sth = $self->get_prepared_query("
    SELECT f.feature_id FROM feature f
    INNER JOIN feature_dbxref fdbx ON f.feature_id = fdbx.feature_id
    INNER JOIN dbxref dbx ON fdbx.dbxref_id = dbx.dbxref_id
    INNER JOIN db ON dbx.db_id = db.db_id
    WHERE db.name = ANY (?) AND dbx.accession = ? AND fdbx.is_current = TRUE
    ");
  $sth->execute($db, $accession);
  my ($feature_id) = $sth->fetchrow_array();
  return unless $feature_id;
  return $self->get_feature($feature_id);
}

sub get_feature_by_genbank_id {
  my ($self, $genbank_id) = @_;
  return undef unless $genbank_id;
  my $sth = $self->get_prepared_query("
    SELECT f.feature_id FROM feature f 
    INNER JOIN feature_dbxref fdbx ON f.feature_id = fdbx.feature_id 
    INNER JOIN dbxref dbx ON fdbx.dbxref_id = dbx.dbxref_id 
    INNER JOIN db ON dbx.db_id = db.db_id
    INNER JOIN organism o ON f.organism_id = o.organism_id
    INNER JOIN cvterm cvt ON f.type_id = cvt.cvterm_id
    INNER JOIN cv ON cvt.cv_id = cv.cv_id
    WHERE 
    db.name = 'GB' 
    AND o.genus = 'Drosophila' AND o.species = 'melanogaster'
    AND cv.name IN('SO', 'sequence') AND cvt.name != 'gene'
    AND dbx.accession = ?
    LIMIT 1
    ");
  # TODO: Don't require fly
#    SELECT f.feature_id FROM feature f 
#    INNER JOIN feature_dbxref fdbx ON f.feature_id = fdbx.feature_id 
#    INNER JOIN dbxref dbx ON fdbx.dbxref_id = dbx.dbxref_id 
#    WHERE 
#    dbx.db_id = 13 AND -- GB
#    f.type_id = 256
#    AND dbx.accession = ?
#    LIMIT 1

  $sth->execute($genbank_id);
  my $row = $sth->fetchrow_hashref();
  return undef if (!$row || !$row->{'feature_id'});
  my $feature = $self->get_feature($row->{'feature_id'});
  return $feature;
}

sub get_datum_id_by_value {
  my ($self, $value) = @_;
  return undef unless $value;
  my $sth = $self->get_prepared_query("SELECT data_id FROM data WHERE value = ?");
  $sth->execute($value);
  my $row = $sth->fetchrow_hashref();
  return undef if (!$row || !$row->{'data_id'});
  my $datum = $self->get_datum($row->{'data_id'});
  return $datum;
}

sub get_normalized_protocol_slots {
  my ($self) = @_;
  if (!scalar(@{$protocol_slots{ident $self}})) {
    log_error "Protocol slots are empty; perhaps you need to call load_experiment(\$experiment_id) first?";
  }
  my @return_protocol_slots;
  for (my $i = 0; $i < scalar(@{$protocol_slots{ident $self}}); $i++) {
    my $protocol_slot = $protocol_slots{ident $self}->[$i];
    for (my $j = 0; $j < scalar(@$protocol_slot); $j++) {
      $return_protocol_slots[$i] = [] if (!defined($return_protocol_slots[$i]));
      $return_protocol_slots[$i]->[$j] = $protocol_slot->[$j]->{'applied_protocol'};
    }
  }
  return \@return_protocol_slots;
}

sub get_denormalized_protocol_slots {
  my ($self) = @_;
  if (!scalar(@{$protocol_slots{ident $self}})) {
    log_error "Protocol slots are empty; perhaps you need to call load_experiment(\$experiment_id) first?";
  }
  my @new_protocol_slots = ($protocol_slots{ident $self}->[0]);
  foreach my $first_applied_protocol (@{$protocol_slots{ident $self}->[0]}) {
    denormalize_applied_protocol($first_applied_protocol, $protocol_slots{ident $self}, \@new_protocol_slots);
  }
  my @return_protocol_slots;
  for (my $i = 0; $i < scalar(@new_protocol_slots); $i++) {
    my $protocol_slot = $new_protocol_slots[$i];
    for (my $j = 0; $j < scalar(@$protocol_slot); $j++) {
      $return_protocol_slots[$i] = [] if (!defined($return_protocol_slots[$i]));
      $return_protocol_slots[$i]->[$j] = $protocol_slot->[$j]->{'applied_protocol'};
    }
  }
  return \@return_protocol_slots;
}

sub get_tsv {
  my ($self, $columns) = @_;
  if (ref($columns) ne 'ARRAY') {
    $columns = $self->get_tsv_columns();
  }
  # This requires that the @$columns array is rectangular; i.e. all columns 
  # are the same length (like breakout before you start playing, not after).
  if (ref($columns->[0]) ne "ARRAY") {
    log_error "Cannot print_tsv a \@columns array that is not an array of arrays";
    return;
  }
  my $expected_length = scalar(@{$columns->[0]});
  foreach my $column (@$columns) {
    if (scalar(@$column) != $expected_length) {
      log_error "Cannot print_tsv a \@columns array that is not a rectangular array of arrays: column " . $column->[0] . " has " . scalar(@$column) . " rows, when $expected_length were expected";
      print STDERR join("\n", map { $_->[0] . str_repeat(".", (120-(length($_->[0])))) . scalar(@$_) } @$columns);
      print STDERR "\n";
      return;
    }
  }
  my $column_length = scalar(@{$columns->[0]});
  my $return_string = "";
  for (my $i = 0; $i < $column_length; $i++) {
    $return_string .= join("\t", map { $_->[$i] } @$columns) . "\n";
  }
  return $return_string;
}

sub get_tsv_columns {
  my ($self) = @_;
  my @protocol_slots;
  if (!scalar(@{$protocol_slots{ident $self}})) {
    log_error "Protocol slots are empty; perhaps you need to call load_experiment(\$experiment_id) first?\n";
    return [];
  }
  my @protocol_slots = ([]);
  foreach my $first_applied_protocol (@{$protocol_slots{ident $self}->[0]}) {
    my $num_duplicate_first_ap = scalar(denormalize_applied_protocol($first_applied_protocol, $protocol_slots{ident $self}, \@protocol_slots));
    for (my $i = 0; $i < $num_duplicate_first_ap; $i++) {
      push @{$protocol_slots[0]}, $first_applied_protocol;
    }
  }
  my @columns;

  # Use seen_data to keep from re-printing out as inputs of the next
  # protocol (which is the way they're stored in Chado, but not the 
  # way they should be printed for MAGE-TAB
  my @seen_data;

  # Build the columns protocol by protocol:
  for (my $i = 0; $i < scalar(@protocol_slots); $i++) {
    my $applied_protocols = $protocol_slots[$i];
    # If this is one of the leftmost (first) protocols, put the inputs 
    # before the protocol name (as with Source Name). This means the 
    # final output will look like:
    # [ Data ] Protocol [ Data Protocol ]* Data
    if ($i == 0) {
      # Collect the inputs into @input_columns, which is an array of arrays
      # (one array for each input + attributes)
      my @input_columns;
      foreach my $applied_protocol (@$applied_protocols) {
        # Inputs go after the protocol if it's not the first protocol
        my @input_data = sort { $a->get_heading() . " [" . $a->get_name() . "]" cmp $b->get_heading() . " [" . $b->get_name() . "]"} $applied_protocol->{'applied_protocol'}->get_input_data(1);
        for (my $i = 0; $i < scalar(@input_data); $i++) {
          my $input = $input_data[$i];
          $input_columns[$i] = [] if (ref($input_columns[$i]) ne "ARRAY");
          $self->flatten_data(@input_columns[$i], $input);
        } 
      }
      # Append all of the arrays in input_columns to the final 
      # @columns array so we end up with:
      # Input [ Attr ]* Input [ Attr ]*
      for (my $i = 0; $i < scalar(@input_columns); $i++) {
        push @columns, @{$input_columns[$i]};
      }
    }

    # Now get the protocol name and attributes (the core of the protocol)
    # and collect the columns into protocol_columns
    my @protocol_columns;
    foreach my $applied_protocol (@$applied_protocols) {
      my $protocol = $applied_protocol->{'applied_protocol'}->get_protocol(1);
      if (!scalar(@protocol_columns)) {
        # Core protocol name
        push @protocol_columns, [ "Protocol REF" ];
        # Protocol termsource
        if ($protocol->get_termsource() && $protocol->get_termsource(1)->get_db()) {
          push @columns, [ "Term Source REF" ];
          if (length($protocol->get_termsource(1)->get_accession())) {
            push @columns, [ "Term Accession Number" ];
          }
        }
        # Protocol attributes
        foreach my $attribute ($protocol->get_attributes(1)) {
          push @protocol_columns, $self->flatten_attribute($attribute);
        }
      }
      my $cur_column = 0;
      push @{$protocol_columns[$cur_column++]}, $protocol->get_name();
      push @{$protocol_columns[$cur_column++]}, $protocol->get_termsource(1)->get_db(1)->get_name() if $protocol->get_termsource() && $protocol->get_termsource(1)->get_db();
      push @{$protocol_columns[$cur_column++]}, $protocol->get_termsource(1)->get_accession() if $protocol->get_termsource() && $protocol->get_termsource(1)->get_accession();
      foreach my $attribute ($protocol->get_attributes(1)) {
        push @{$protocol_columns[$cur_column++]}, $attribute->get_value();
        push @{$protocol_columns[$cur_column++]}, $attribute->get_termsource(1)->get_db(1)->get_name() if $attribute->get_termsource() && $attribute->get_termsource(1)->get_db();
        push @{$protocol_columns[$cur_column++]}, $attribute->get_termsource(1)->get_accession() if $attribute->get_termsource() && $attribute->get_termsource(1)->get_accession();
      }
    }
    # Push the protocol's columns onto the final @columns array
    push @columns, @protocol_columns;

    # If this is NOT one of the leftmost (first) protocols, put the inputs 
    # after the protocol name.
    if ($i > 0) {
      my @input_columns;
      foreach my $applied_protocol (@$applied_protocols) {
        # Inputs go after the protocol if it's not the first protocol
        my @input_data = sort { $a->get_heading() . " [" . $a->get_name() . "]" cmp $b->get_heading() . " [" . $b->get_name() . "]"} $applied_protocol->{'applied_protocol'}->get_input_data(1);
        for (my $i = 0; $i < scalar(@input_data); $i++) {
          my $input = $input_data[$i];
          $input_columns[$i] = [] if (ref($input_columns[$i]) ne "ARRAY");
          my @is_seen = grep { $_ == $input->get_id} @seen_data;
          # If this datum has already been used as an output from the previous
          # set of protocols, then it shouldn't be reprinted as an input here
          if (!scalar(@is_seen)) {
            $self->flatten_data(@input_columns[$i], $input, $i);
          }
        } 
      }
      for (my $i = 0; $i < scalar(@input_columns); $i++) {
        push @columns, @{$input_columns[$i]};
      }
    }

    # Now get the outputs, which go after the inputs after the protocol.
    # Make sure to track what outputs are used in @seen_data so we don't 
    # reprint them as inputs in the next set of protocols
    @seen_data = ();
    my @output_columns;
    foreach my $applied_protocol (@$applied_protocols) {
      my @output_data = sort { $a->get_heading() . " [" . $a->get_name() . "]" cmp $b->get_heading() . " [" . $b->get_name() . "]"} $applied_protocol->{'applied_protocol'}->get_output_data(1);
      for (my $i = 0; $i < scalar(@output_data); $i++) {
        my $output = $output_data[$i];
        $output_columns[$i] = [] if (ref($output_columns[$i]) ne "ARRAY");
        $self->flatten_data(@output_columns[$i], $output);
        push @seen_data, $output->get_id();
      } 
    }
    for (my $i = 0; $i < scalar(@output_columns); $i++) {
      push @columns, @{$output_columns[$i]};
    }
  }

  return \@columns;
}
sub xml_unescape : RESTRICTED {
  my ($value) = @_;
  $value =~ s/&gt;/>/g;
  $value =~ s/&lt;/</g;
  $value =~ s/&quot;/"/g;
  $value =~ s/&#39;/'/g;
  $value =~ s/&amp;/&/g;
  return $value;
}

sub denormalize_applied_protocol : PRIVATE {
  my ($applied_protocol, $protocol_slots, $new_protocol_slots, $slotnum) = @_;
  $slotnum ||= 1; # don't start at the 0th slot; that one doesn't have any previous protocols
  if (!defined($protocol_slots->[$slotnum])) {
    return (1);
  }
  my $next_applied_protocols = $protocol_slots->[$slotnum];
  my $previous_applied_protocol_id = $applied_protocol->{'applied_protocol'}->get_id();
  my @these_protocols;

  # For each applied protocol in the current slot
  foreach my $next_applied_protocol (@$next_applied_protocols) {
    my $this_ap_follows_prev_ap = scalar(grep { $previous_applied_protocol_id == $_} @{$next_applied_protocol->{'previous_applied_protocol_id'}});
    # Get the IDs of applied protocols in the previous slot that have data used in this one
    if ($this_ap_follows_prev_ap) {
      my @next_rows = denormalize_applied_protocol($next_applied_protocol, $protocol_slots, $new_protocol_slots, $slotnum+1);
      for (my $i = 0; $i < scalar(@next_rows); $i++) {
        push @these_protocols, $next_applied_protocol;
      }
    }
  }

  push @{$new_protocol_slots->[$slotnum]}, @these_protocols;
  return @these_protocols;
}

sub get_prepared_query : PRIVATE {
  my ($self, $query) = @_;
  if ($self->get_dbh()) {
    if (!defined($prepared_queries{ident $self}->{$query})) {
      $prepared_queries{ident $self}->{$query} = $self->get_dbh()->prepare($query);
    }
    return $prepared_queries{ident $self}->{$query};
  } else {
    log_error "Can't get the prepared query '$query' with no database connection.", "error";
    exit;
  }
}

sub flatten_data : PRIVATE {
  my ($self, $data_columns, $datum, $num) = @_;

  my $cur_column = 0;
  if (!scalar(@$data_columns)) {
    push @$data_columns, $self->get_data_column_headings($datum);
  }
  push @{$data_columns->[$cur_column++]}, $datum->get_value();
  push @{$data_columns->[$cur_column++]}, $datum->get_termsource(1)->get_db(1)->get_name() if $datum->get_termsource() && $datum->get_termsource(1)->get_db();
  push @{$data_columns->[$cur_column++]}, $datum->get_termsource(1)->get_accession() if $datum->get_termsource() && $datum->get_termsource(1)->get_accession();
  foreach my $attribute ($datum->get_attributes(1)) {
    push @{$data_columns->[$cur_column++]}, $attribute->get_value();
    push @{$data_columns->[$cur_column++]}, $attribute->get_termsource(1)->get_db(1)->get_name() if $attribute->get_termsource() && $attribute->get_termsource(1)->get_db();
    push @{$data_columns->[$cur_column++]}, $attribute->get_termsource(1)->get_accession() if $attribute->get_termsource() && $attribute->get_termsource(1)->get_accession();
  }
}

sub get_data_column_headings : PRIVATE {
  my ($self, $datum) = @_;
#  if (
#    $datum->get_type() && $datum->get_type()->get_name() eq "anonymous_datum" &&
#    $datum->get_type()->get_cv() && $datum->get_type()->get_cv()->get_name eq "modencode"
#    $datum->get_heading() =~ /^Anonymous Datum/
#  ) { 
#    # Skip "anonymous" data
#    return; 
#  }
  my @columns;
  # Datum heading and name
  my $datum_heading = $datum->get_heading();
  if (length($datum->get_name())) {
    $datum_heading .= "[" . $datum->get_name() . "]" if (length($datum->get_name()));
  }
  # Datum type
  if ($datum->get_type() && length($datum->get_type(1)->get_name()) && !($datum->get_type(1)->get_cv() && $datum->get_type(1)->get_cv(1)->get_name eq "mage")) {
    $datum_heading .= "(";
    $datum_heading .= $datum->get_type(1)->get_cv(1)->get_name() . ":" if ($datum->get_type(1)->get_cv() && length($datum->get_type(1)->get_cv(1)->get_name()));
    $datum_heading .= $datum->get_type(1)->get_name() . ")";
  }
  push @columns, [ $datum_heading ];

  # Datum termsource
  if ($datum->get_termsource() && $datum->get_termsource(1)->get_db()) {
    push @columns, [ "Term Source REF" ];
    if (length($datum->get_termsource(1)->get_accession())) {
      push @columns, [ "Term Accession Number" ];
    }
  }

  # Datum attributes
  foreach my $attribute ($datum->get_attributes(1)) {
    push @columns, $self->flatten_attribute($attribute);
  }

  return @columns;
}

sub flatten_attribute : PRIVATE {
  my ($self, $attribute) = @_;
  my @columns;
  # Attribute heading and name
  my $attribute_heading = $attribute->get_heading();
  if (length($attribute->get_name())) {
    $attribute_heading .= "[" . $attribute->get_name() . "]" if (length($attribute->get_name()));
  }
  # Attribute type
  if ($attribute->get_type() && length($attribute->get_type(1)->get_name()) && !($attribute->get_type(1)->get_cv() && $attribute->get_type(1)->get_cv(1)->get_name eq "mage")) {
    $attribute_heading .= "(";
    $attribute_heading .= $attribute->get_type(1)->get_cv(1)->get_name() . ":" if ($attribute->get_type(1)->get_cv() && length($attribute->get_type(1)->get_cv(1)->get_name()));
    $attribute_heading .= $attribute->get_type(1)->get_name() . ")";
  }
  push @columns, [ $attribute_heading ];
  # Attribute termsource
  if ($attribute->get_termsource() && $attribute->get_termsource(1)->get_db()) {
    push @columns, [ "Term Source REF" ];
    if (length($attribute->get_termsource(1)->get_accession())) {
      push @columns, [ "Term Accession Number" ];
    }
  }

  return @columns;
}

sub get_dbh : PRIVATE {
  my ($self, $suppress_warnings) = @_;
  
  if (!defined($dbh{ident $self}) || !$dbh{ident $self} || ($dbh{ident $self} && !($dbh{ident $self}->{Active}))) {
    return undef unless defined($self->get_dbname());
    my $dsn = "dbi:Pg:dbname=" . $self->get_dbname();
    $dsn .= ";host=" . $self->get_host() if defined($self->get_host());
    $dsn .= ";port=" . $self->get_port() if defined($self->get_port());
    eval {
      $dbh{ident $self} = DBI->connect($dsn, $self->get_username(), $self->get_password(), { RaiseError => 1, AutoCommit => 0 });
    };

    if (!$suppress_warnings && (!defined($dbh{ident $self}) || !$dbh{ident $self})) {
      log_error "Couldn't connect to data source \"$dsn\", using username \"" . $self->get_username() . "\" and password \"" . $self->get_password() . "\"\n  " . $DBI::errstr;
      return 0;
    }
  }

  return $dbh{ident $self};
}

sub set_schema {
  my ($self, $schema) = @_;
  $schema ||= "public";

  $schema =~ s/;/_/g;

  $schema{ident $self} = $schema;
  $dbh{ident $self}->do("SET search_path = $schema");

  my ($experiment_name) = $dbh{ident $self}->selectrow_array("SELECT uniquename FROM experiment");
  return $experiment_name;
}

sub str_repeat : PRIVATE {
  my ($str, $count)  = @_;
  my $newstr = "";;
  for (my $i = 0; $i < $count; $i++) {
    $newstr .= $str;
  }
  return $newstr;
}

sub get_experiment_props_by_name {
  my ($self, $experiment_prop_name) = @_;
  my @exp_props;
  my $experiment_prop_sth = $self->get_prepared_query("SELECT name, type_id, dbxref_id, value, rank FROM experiment_prop WHERE name = ?");
  $experiment_prop_sth->execute($experiment_prop_name);
  while (my $row = $experiment_prop_sth->fetchrow_hashref()) {
    map { $row->{$_} = xml_unescape($row->{$_}) } keys(%$row);
    my $property = new ModENCODE::Chado::ExperimentProp({
        'experiment' => $experiment{ident $self},
        'name' => $row->{'name'},
        'value' => $row->{'value'},
        'rank' => $row->{'rank'},
      });
    my $termsource = $self->get_termsource($row->{'dbxref_id'});
    $property->get_object->set_termsource($termsource) if $termsource;
    my $type = $self->get_type($row->{'type_id'});
    $property->get_object->set_type($type) if $type;
    push @exp_props, $property;
  }
  return @exp_props;
}



1;
