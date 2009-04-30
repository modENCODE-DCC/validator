package ModENCODE::Validator::Data::GEO_lite;
=pod

=head1 NAME

ModENCODE::Validator::Data::GEO_lite - Class for validating and updating
BIR-TAB L<Data|ModENCODE::Chado::Data> objects containing GenBank accessions for
GEO samples.

=head1 SYNOPSIS

This class is meant to be used to build a L<ModENCODE::Chado::Data::Attribute> object
(and associated L<CVTerms|ModENCODE::Chado::CVTerm> and
LOrganismDBXref|ModENCODE::Chado::Organism>s) for a provided NCBI GEO
accession. This is a temporary standin until GEO records can be properly fetched from GEO repository.

To use this validator in a standalone way:

  my $datum = new ModENCODE::Chado::Data({
    'value' => 'GEOID'
  });
  my $validator = new ModENCODE::Validator::Data::GEO_lite();
  $validator->add_datum($datum, $applied_protocol);
  if ($validator->validate()) {
    my $new_datum = $validator->merge($datum);
    print $new_datum->get_features()->[0]->get_name();
  }

Note that this class is not meant to be used directly, rather it is mean to be
used within L<ModENCODE::Validator::Data>.

=head1 PREWRITTEN FEATURES

In order to cut down on memory usage, this modules opens a temporary file in the
directory that the Perl script exists in (not necessarily the current
directory), and adds it to the list of temporary files that will be written out
by L<ModENCODE::Chado::XMLWriter|ModENCODE::Chado::XMLWriter/PREWRITTEN
FEATURES>. Admittedly, this creates some strong linkages between the validation
code and the XMLWriter, so it should probably be made optional eventually. The
L<ModENCODE::Chado::Feature>s actually generated during the L</merge($datum,
$applied_protocol)> step are therefore just placeholder features with the
L<chadoxml_id|ModENCODE::Chado::Feature/get_chadoxml_id() |
set_chadoxml_id($chadoxml_id)> set to the same value as the feature written out
to XML.

=head1 FUNCTIONS

=over

=item validate()

Makes sure that all of the data added using L<add_datum($datum,
$applied_protocol)|ModENCODE::Validator::Data::Data/add_datum($datum,
$applied_protocol)> have values that exist as GenBank EST accession in either
the local modENCODE database, FlyBase, or GenBank.

=item merge($datum, $applied_protocol)

Given an original L<datum|ModENCODE::Chado::Data> C<$datum>,
returns a copy of that datum with a newly attached feature based on an EST
record in either the local modENCODE database, FlyBase, or GenBank for the value
in that C<$datum>.

B<NOTE:> In addition to attaching features to the current C<$datum>, if there is
a GFF3 datum (as validated by L<ModENCODE::Validator::Data::GFF3>) attached to
the same C<$applied_protocol>, then the features within it are scanned for any
with the name equal to the EST accession - if these are found, they are replaced
(using L<ModENCODE::Chado::Feature/mimic($feature)>).

=back

=head1 SEE ALSO

L<ModENCODE::Chado::Data>, L<ModENCODE::Validator::Data>,
L<ModENCODE::Validator::Data::Data>, L<ModENCODE::Chado::Feature>,
L<ModENCODE::Chado::CVTerm>, L<ModENCODE::Chado::Organism>,
L<ModENCODE::Chado::FeatureLoc>,
L<ModENCODE::Validator::Data::Result_File>,
L<ModENCODE::Validator::Data::WIG>, L<ModENCODE::Validator::Data::GFF3>,

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use base qw( ModENCODE::Validator::Data::Data );
use Class::Std;
use Carp qw(croak carp);
use SOAP::Lite;
use Bio::FeatureIO;
use ModENCODE::Chado::Feature;
use ModENCODE::Chado::CVTerm;
use ModENCODE::Chado::CV;
use ModENCODE::Chado::Organism;
use ModENCODE::Parser::Chado;
use ModENCODE::ErrorHandler qw(log_error);
#use ModENCODE::Validator::TermSources;
use XML::XPath;

use constant ESTS_AT_ONCE => 40;
use constant MAX_TRIES => 2;

my %soap_client                 :ATTR( :get<soap_client> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  $soap_client{$ident} = SOAP::Lite->service('http://www.ncbi.nlm.nih.gov/entrez/eutils/soap/eutils.wsdl');
  $soap_client{$ident}->serializer->envprefix('SOAP-ENV');
  $soap_client{$ident}->serializer->encprefix('SOAP-ENC');
  $soap_client{$ident}->serializer->soapversion('1.1');
  $soap_client{$ident}->want_som(1);
}

sub validate {
  my ($self) = @_;
  my $success = 1;

  # Get out the EST IDs we need to validate
  log_error "Validating presence of " . $self->num_data . " GEO submission(s).", "notice", ">";
  
  log_error "Checking Chado databases...", "notice", ">";
  foreach my $parse (
    ['modENCODE', $self->get_modencode_chado_parser()],
    #assuming these won't be in Fly/Wormbase
    #['FlyBase', $self->get_flybase_chado_parser()],
    #['WormBase',  $self->get_wormbase_chado_parser()],
  ) {
    my ($parser_name, $parser) = @$parse;
    if (!$parser) {
      log_error "Can't check accessions against the $parser_name database; skipping.", "warning";
      next;
    }

    log_error "Checking for " . $self->num_data . " GEO accessions already in the $parser_name database...", "notice", ">";
    while (my $ap_datum = $self->next_datum) {
      my ($applied_protocol, $direction, $datum) = @$ap_datum;

      my $datum_obj = $datum->get_object;
      my $accession = $datum_obj->get_value;

      if (!length($accession)) {
        log_error "Empty value for GEO accession in column " . $datum_obj->get_heading . " [" . $datum_obj->get_name . "].", "warning";
        $self->remove_current_datum;
        next;
      }

      my $feature = $parser->get_feature_by_genbank_id($datum_obj->get_value);
      next unless $feature;

      my $cvterm = $feature->get_object->get_type(1)->get_name;
      my $cv = $feature->get_object->get_type(1)->get_cv(1)->get_name;
      my $canonical_cvname = ModENCODE::Config::get_cvhandler()->get_cv_by_name($cv)->{'names'}->[0];

      if ($cvterm ne "GEO_record") {
        log_error "Found a feature in $parser_name, but it is of type '$cv:$cvterm', not 'ME:GEO_record'. Not using it.", "warning";
        next;
      }
      if ($canonical_cvname ne "modencode-helper") {
        # TODO: Use this and update the CV type?
        log_error "Found a feature in $parser_name, but it is of type '$cv:$cvterm', not 'SO:EST'. Not using it.", "warning";
        next;
      }
      
      # If we found it, don't need to keep trying to validate it
      $datum->get_object->add_feature($feature);
      $self->remove_current_datum;
    }
    log_error "Done; " . $self->num_data . " accessions still to be found.", "notice", "<";

    $self->rewind();
  }
  log_error "Done.", "notice", "<";

  unless ($self->num_data) {
    log_error "Done.", "notice", "<";
    return $success;
  }

  # Validate remaining ESTs against GenBank by primary ID
  log_error "Looking up " . $self->num_data . " accessions in GEO " , "notice", ">";

  my @not_found_by_acc;
  while ($self->num_data) {
    # Get 40 GEO records at a time and search for them at NCBI
    my @batch_query;
    my $num_ests = 0;
    while (my $ap_datum = $self->next_datum) {
      push @batch_query, $ap_datum;
      $self->remove_current_datum; # This is the last chance this EST gets to be found
      last if (++$num_ests >= ESTS_AT_ONCE);
    }
    
    my $fetch_query = join(",", map { $_->[2]->get_object->get_value } @batch_query);
    if (scalar(@batch_query) < 10) {
	log_error ("Fetching GEO ids: " .  $fetch_query . ".", "notice", ">");
    } else {
    log_error "Fetching batch of " . scalar(@batch_query) . " GEO accessions.", "notice", ">";
    }

    my $done = 0;


    # Do we need to fall back to searching because we couldn't find by accession?
    while ($done++ < MAX_TRIES) {
      log_error "Searching for remaining batch of " . scalar(@batch_query) . " GEO accessions.", "notice";

      # Run query (est1,est2,...) and get back the cookie that will let us fetch the result:
      my $search_query = join(" OR ", map { $_->[2]->get_object->get_value } @batch_query);
      my $fetch_results = $search_query;
      my ($not_found, $false_positives) = handle_summary_results($fetch_results, @batch_query);


      # Keep track of $not_found and to pass on to next segment
      push @not_found_by_acc, @$not_found;

      last; # Exit the retry 'til MAX_TRIES loop
    }
    if ($done > MAX_TRIES) {
      # ALL of the queries failed, so pass on all the ESTs being queried to the next section
      log_error "Couldn't fetch GEO accessions by ID after " . MAX_TRIES . " tries.", "warning";
      @not_found_by_acc = @batch_query;
    }
    # If we found everything, move on to the next batch of ESTs
    unless (scalar(@not_found_by_acc)) {
      sleep 5; # Make no more than one request every 3 seconds (2 for flinching, Milo)
      log_error "Done.", "notice", "<";
      next; # SUCCESS
    }
    log_error "Done.", "notice", "<";

    ###### ERROR - DIDN'T FIND ALL ESTS ######
    $success = 0;
    foreach my $missing_est (@not_found_by_acc) {
      my $datum_obj = $missing_est->[2]->get_object;
      log_error "Didn't find accession " . $datum_obj->get_value . " anywhere!", "error";
    }
    log_error "Done.", "notice", "<";
  }
  log_error "Done.", "notice", "<";

  log_error "Done.", "notice", "<";
  return $success;
}


sub handle_summary_results {
  my ($fetch_results, @ap_data) = @_;
  my @ests_not_found;
  my @unmatched_result_accs = @ap_data;
  foreach my $ap_datum (@ap_data) {
    my ($applied_protocol, $direction, $datum) = @$ap_datum;
    my $datum_obj = $datum->get_object;

    # Pull out enough information from the GenBank record to create a Chado feature
    #create a dummy dbxref

    my $genbank_acc = $datum_obj->get_value();

    log_error "Creating a url attribute for $genbank_acc", "notice";

    
    my $url = "http://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=" . $genbank_acc;
    $datum_obj->add_attribute(new ModENCODE::Chado::DatumAttribute({
          'value' => $url,
          'type' => new ModENCODE::Chado::CVTerm({'name' => 'anyURI', 'cv' => new ModENCODE::Chado::CV({'name' => 'xsd'})}),
          'name' => 'URL',
          'heading' => 'GEO record link',
          'datum' => $datum,
	 })
	);

  }

  return (\@ests_not_found, \@unmatched_result_accs);
}



sub get_flybase_chado_parser : PROTECTED {
  my ($self) = @_;
  my $parser = new ModENCODE::Parser::Chado({
      'dbname' => ModENCODE::Config::get_cfg()->val('databases flybase', 'dbname'),
      'host' => ModENCODE::Config::get_cfg()->val('databases flybase', 'host'),
      'port' => ModENCODE::Config::get_cfg()->val('databases flybase', 'port'),
      'username' => ModENCODE::Config::get_cfg()->val('databases flybase', 'username'),
      'password' => ModENCODE::Config::get_cfg()->val('databases flybase', 'password'),
      'caching' => 0,
    });
  return undef unless $parser;
  $parser->set_no_relationships(1);
  return $parser;
}

sub get_wormbase_chado_parser : PROTECTED {
  my ($self) = @_;
  my $parser = new ModENCODE::Parser::Chado({
      'dbname' => ModENCODE::Config::get_cfg()->val('databases wormbase', 'dbname'),
      'host' => ModENCODE::Config::get_cfg()->val('databases wormbase', 'host'),
      'port' => ModENCODE::Config::get_cfg()->val('databases wormbase', 'port'),
      'username' => ModENCODE::Config::get_cfg()->val('databases wormbase', 'username'),
      'password' => ModENCODE::Config::get_cfg()->val('databases wormbase', 'password'),
      'caching' => 0,
    });
  return undef unless $parser;
  $parser->set_no_relationships(1);
  return $parser;
}

sub get_modencode_chado_parser : PROTECTED {
  my ($self) = @_;
  my $parser = new ModENCODE::Parser::Chado({
      'dbname' => ModENCODE::Config::get_cfg()->val('databases modencode', 'dbname'),
      'host' => ModENCODE::Config::get_cfg()->val('databases modencode', 'host'),
      'port' => ModENCODE::Config::get_cfg()->val('databases modencode', 'port'),
      'username' => ModENCODE::Config::get_cfg()->val('databases modencode', 'username'),
      'password' => ModENCODE::Config::get_cfg()->val('databases modencode', 'password'),
      'caching' => 0,
    });
  return undef unless $parser;
  $parser->set_no_relationships(1);
  return $parser;
}

sub parse_summaryXML : PRIVATE {
    return;
}


1;
