package ModENCODE::Validator::Data::dbEST_acc;
=pod

=head1 NAME

ModENCODE::Validator::Data::dbEST_acc - Class for validating and updating
BIR-TAB L<Data|ModENCODE::Chado::Data> objects containing GenBank accessions for
ESTs to include L<Features|ModENCODE::Chado::Feature> for those ESTs.

=head1 SYNOPSIS

This class is meant to be used to build a L<ModENCODE::Chado::Feature> object
(and associated L<CVTerms|ModENCODE::Chado::CVTerm> and
LOrganismDBXref|ModENCODE::Chado::Organism>s) for a provided GenBank EST
accession. EST information will potentially be fetched from a few different
sources, depending on availability. If the EST in question is already in the
local modENCODE Chado database (defined in the C<[databases modencode]> section of
the ini-file loaded by L<ModENCODE::Config>), then a feature will be created
from there. If it's unavailable in the modENCODE database, this module will fall
back to the FlyBase Chado database defined in the C<[databases flybase]> section
of the ini-file. If the EST still cannot be found, a search is run via the
GenBank SOAP eutils interface, and the EST feature is built from the GenBank
dbEST record.

=head1 USAGE

The goal of using multiple sources is to reduce the impact on outside
repositories (e.g. FlyBase and GenBank), since these resources are often under
load or are otherwise restricting connections. This also ends up vastly
increasing speed for large numbers of ESTs that can be found in one of the
databases.

When given L<ModENCODE::Chado::Data> objects with values that are GenBank EST
accessions, this module first uses
L<ModENCODE::Parser::Chado/get_feature_by_genbank_id($genbank_id)> to fetch the
EST from the modENCODE database, then again to fetch the EST from FlyBase. If
both of these fail, all of the EST accessions left are grouped into batches of
40, and sent to the GenBank eSearch service of eUtils (using the SOAP interface,
rather than the regular URL-based interface). The features returned by the
search are then pulled down using the SOAP eFetch service, and then all of the
features returned are scanned to make sure they actually match the ESTs being
searched for and aren't just fuzzy search results.

To use this validator in a standalone way:

  my $datum = new ModENCODE::Chado::Data({
    'value' => 'ESTACCESSION'
  });
  my $validator = new ModENCODE::Validator::Data::dbEST_acc();
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
L<ModENCODE::Chado::FeatureLoc>, L<ModENCODE::Validator::Data::BED>,
L<ModENCODE::Validator::Data::Result_File>,
L<ModENCODE::Validator::Data::SO_transcript>,
L<ModENCODE::Validator::Data::WIG>, L<ModENCODE::Validator::Data::GFF3>,
L<ModENCODE::Validator::Data::dbEST_acc_list>

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
use LWP::UserAgent;
#use ModENCODE::Validator::TermSources;

use constant ESTS_AT_ONCE => 40;
use constant MAX_TRIES => 2;

my %soap_client                 :ATTR( :get<soap_client> );

sub BUILD {
  my ($self, $ident, $args) = @_;

  # Cache WSDL
  my $root_dir = ModENCODE::Config::get_root_dir();
  my $wsdl_url = 'http://www.ncbi.nlm.nih.gov/entrez/eutils/soap/eutils.wsdl';
  my $cache_wsdl = $root_dir . "ontology_cache/eutils.wsdl";
  my $useragent = new LWP::UserAgent();
  my $res = $useragent->mirror($wsdl_url, $cache_wsdl);
  if (!$res->is_success) {
    if ($res->code == 304) {
      log_error "Using cached copy of NCBI EUtils WSDL for fetching ESTs; no change on server.", "notice";
    } else {
      log_error "Can't fetch a copy of the NCBI EUtils WSDL for fetching ESTs.", "warning";
      if (!(-r $cache_wsdl)) {
        log_error "Couldn't fetch a copy of NCBI EUtils WSDL found, and no cached version found.", "error";
      }
    }
  }

  $soap_client{$ident} = SOAP::Lite->service("file:$cache_wsdl");
  $soap_client{$ident}->serializer->envprefix('SOAP-ENV');
  $soap_client{$ident}->serializer->encprefix('SOAP-ENC');
  $soap_client{$ident}->serializer->soapversion('1.1');
  $soap_client{$ident}->want_som(1);
}

sub validate {
  my ($self) = @_;
  my $success = 1;

  # Get out the EST IDs we need to validate
  log_error "Validating presence of " . $self->num_data . " ESTs.", "notice", ">";
  
  log_error "Checking Chado databases...", "notice", ">";
  foreach my $parse (
    ['modENCODE', $self->get_modencode_chado_parser()],
    ['FlyBase', $self->get_flybase_chado_parser()],
    ['WormBase',  $self->get_wormbase_chado_parser()],
  ) {
    my ($parser_name, $parser) = @$parse;
    if (!$parser) {
      log_error "Can't check ESTs against the $parser_name database; skipping.", "warning";
      next;
    }

    log_error "Checking for " . $self->num_data . " ESTs already in the $parser_name database...", "notice", ">";
    while (my $ap_datum = $self->next_datum) {
      my ($applied_protocol, $direction, $datum) = @$ap_datum;

      my $datum_obj = $datum->get_object;
      my $accession = $datum_obj->get_value;

      if (!length($accession)) {
        log_error "Empty value for EST accession in column " . $datum_obj->get_heading . " [" . $datum_obj->get_name . "].", "warning";
        $self->remove_current_datum;
        next;
      }

      my $feature = $parser->get_feature_by_genbank_id($datum_obj->get_value);
      next unless $feature;

      my $cvterm = $feature->get_object->get_type(1)->get_name;
      my $cv = $feature->get_object->get_type(1)->get_cv(1)->get_name;
      my $canonical_cvname = ModENCODE::Config::get_cvhandler()->get_cv_by_name($cv)->{'names'}->[0];

      if ($cvterm ne "EST") {
        log_error "Found a feature in $parser_name, but it is of type '$cv:$cvterm', not 'SO:EST'. Not using it.", "warning";
        next;
      }
      if ($canonical_cvname ne "SO") {
        # TODO: Use this and update the CV type?
        log_error "Found a feature in $parser_name, but it is of type '$cv:$cvterm', not 'SO:EST'. Not using it.", "warning";
        next;
      }
      
      # If we found it, don't need to keep trying to validate it
      $datum->get_object->add_feature($feature);
      $self->remove_current_datum;
    }
    log_error "Done; " . $self->num_data . " ESTs still to be found.", "notice", "<";

    $self->rewind();
  }
  log_error "Done.", "notice", "<";

  unless ($self->num_data) {
    log_error "Done.", "notice", "<";
    return $success;
  }

  # Validate remaining ESTs against GenBank by primary ID
  log_error "Looking up " . $self->num_data . " ESTs in dbEST.", "notice", ">";

  my @not_found_by_acc;
  while ($self->num_data) {
    # Get 40 ESTs at a time and search for them at dbEST
    my @batch_query;
    my $num_ests = 0;
    while (my $ap_datum = $self->next_datum) {
      push @batch_query, $ap_datum;
      $self->remove_current_datum; # This is the last chance this EST gets to be found
      last if (++$num_ests >= ESTS_AT_ONCE);
    }
    
    log_error "Fetching batch of " . scalar(@batch_query) . " ESTs.", "notice", ">";
    my $fetch_query = join(",", map { $_->[2]->get_object->get_value } @batch_query);

    my $done = 0;
    while ($done++ < MAX_TRIES) {

      # Run query (est1,est2,...) and get back the cookie that will let us fetch the result:
      my $fetch_results;
      eval {
        $fetch_results = $self->get_soap_client->run_eFetch({
            'eFetchRequest' => {
              'db' => 'nucest',
              'id' => $fetch_query,
              'tool' => 'modENCODE pipeline',
              'email' => 'yostinso@berkeleybop.org',
              'retmax' => 400,
            }
          });
      };

      if (!$fetch_results) {
        # Couldn't get anything useful back (bad network connection?). Wait 30 seconds and retry.
        log_error "Couldn't retrieve any ESTs by ID; got no response from NCBI. Retrying in 30 seconds.", "notice";
        sleep 30;
        next;
      }

      if ($fetch_results->fault) {
        # Got back a SOAP fault, which means our query got through but NCBI gave us junk back.
        # Wait 30 seconds and retry - this seems to just happen sometimes.
        log_error "Couldn't fetch ESTs by primary ID; got response \"" . $fetch_results->faultstring . "\" from NCBI. Retrying in 30 seconds.", "notice";
        sleep 30;
        next;
      }

      # No errors, pull out the results
      $fetch_results->match('/Envelope/Body/eFetchResult/GBSet/GBSeq');
      if (!length($fetch_results->valueof())) {
        if (!$fetch_results->match('/Envelope/Body/eFetchResult')) {
          # No eFetchResult result at all, which means we got back junk. Wait 30 seconds and retry.
          log_error "Couldn't retrieve EST by ID; got a junk response from NCBI. Retrying in 30 seconds.", "notice";
          sleep 30;
          next;
        } else {
          # Got an empty result
          log_error "None of the " . scalar(@batch_query) . " ESTs found at NCBI using using query '" . $fetch_query . "'. Retrying, just in case.", "warning";
          sleep 5;
          next;
        }
      }

      # Got back an array of useful results. Figure out which of our current @term_set actually
      # got returned. Record ones that we didn't get back in @data_left.
      my ($not_found, $false_positives) = handle_search_results($fetch_results, @batch_query);

      if (scalar(@$false_positives)) {
        # TODO: Do more here?
        log_error "Found " . scalar(@$false_positives) . " false positives at GenBank: [" . join(", ", map { $_ } @$false_positives) .  "] ", "warning";
      }

      # Keep track of $not_found and to pass on to next segment
      push @not_found_by_acc, @$not_found;

      last; # Exit the retry 'til MAX_TRIES loop
    }
    if ($done > MAX_TRIES) {
      # ALL of the queries failed, so pass on all the ESTs being queried to the next section
      log_error "Couldn't fetch ESTs by ID after " . MAX_TRIES . " tries.", "warning";
      @not_found_by_acc = @batch_query;
    }
    # If we found everything, move on to the next batch of ESTs
    unless (scalar(@not_found_by_acc)) {
      sleep 5; # Make no more than one request every 3 seconds (2 for flinching, Milo)
      log_error "Done.", "notice", "<";
      next; # SUCCESS
    }


    @batch_query = @not_found_by_acc;
    @not_found_by_acc = ();

    ###### FALL BACK TO SEARCH INSTEAD OF LOOKUP ######

    # Do we need to fall back to searching because we couldn't find by accession?
    log_error "Falling back to pulling down " . scalar(@batch_query) . " EST information from Genbank by searching...", "notice", ">";
    $done = 0;
    while ($done++ < MAX_TRIES) {
      log_error "Searching for remaining batch of " . scalar(@batch_query) . " ESTs.", "notice";

      # Run query (est1,est2,...) and get back the cookie that will let us fetch the result:
      my $search_query = join(" OR ", map { $_->[2]->get_object->get_value } @batch_query);

      # Run query and get back the cookie that will let us fetch the result:
      my $search_results;
      eval {
        $search_results = $self->get_soap_client->run_eSearch({
            'eSearchRequest' => {
              'db' => 'nucleotide',
              #   'rettype' => 'native',
              'term' => $search_query,
              'tool' => 'modENCODE pipeline',
              'email' => 'yostinso@berkeleybop.org',
              'usehistory' => 'y',
              'retmax' => 400,
            }
          });
      };
      if (!$search_results) {
        # Couldn't get anything useful back (bad network connection?). Wait 30 seconds and retry.
        log_error "Couldn't retrieve any ESTs by searching; got no response from NCBI. Retrying in 30 seconds.", "notice";
        sleep 30;
        next;
      }

      if ($search_results->fault) {
        # Got back a SOAP fault, which means our query got through but NCBI gave us junk back.
        # Wait 30 seconds and retry - this seems to just happen sometimes.
        log_error "Couldn't search for ESTs by primary ID; got response \"" . $search_results->faultstring . "\" from NCBI. Retrying in 30 seconds.", "notice";
        sleep 30;
        next;
      }

      # Pull out the cookie and query key that will allow us to actually fetch the results proper
      $search_results->match('/Envelope/Body/eSearchResult/WebEnv');
      my $webenv = $search_results->valueof();
      $search_results->match('/Envelope/Body/eSearchResult/QueryKey');
      my $querykey = $search_results->valueof();

      if (!length($querykey) || !length($webenv)) {
        # If we didn't get a valid query key or cookie, something screwy happened without a fault.
        # Wait 30 seconds and retry.
        log_error "Couldn't get a search cookie when searching for ESTs; got an unexpected response from NCBI. Retrying in 30 seconds.", "notice";
        sleep 30;
        next;
      }

      ######################################################################################

      # Okay, got a valid query key and cookie, go ahead and fetch the actual results.

      my $fetch_results;
      eval {
        $fetch_results = $self->get_soap_client->run_eFetch({
            'eFetchRequest' => {
              'db' => 'nucleotide',
	      #'rettype' => 'native',
              'WebEnv' => $webenv,
              'query_key' => $querykey,
              'tool' => 'modENCODE pipeline',
              'email' => 'yostinso@berkeleybop.org',
              'retmax' => 1000,
            }
          });
      };

      if (!$fetch_results) {
        # Couldn't get anything useful back (bad network connection?). Wait 30 seconds and retry.
        log_error "Couldn't retrieve any ESTs by search result; got no response from NCBI. Retrying in 30 seconds.", "notice";
        sleep 30;
        next;
      }

      if ($fetch_results->fault) {
        # Got back a SOAP fault, which means our query got through but NCBI gave us junk back.
        # Sadly, this is also what happens when there are no results. The standard Eutils response 
        # is "Error: download dataset is empty", which apparently translates to a SOAP fault. Since
        # the search itself worked, we'll assume that NCBI didn't just die and that what we're really
        # seeing is a lack of results, in which all of the ESTs being searched for failed.
        log_error "Couldn't fetch ESTs by primary ID; got response \"" . $fetch_results->faultstring . "\" from NCBI. Retrying, just in case.", "error";
        sleep 5;
        last;
      }

      if (!length($fetch_results->valueof())) {
        if (!$fetch_results->match('/Envelope/Body/eFetchResult')) {
          # No eFetchResult result at all, which means we got back junk. Wait 30 seconds and retry.
          log_error "Couldn't retrieve EST by ID; got an unknown response from NCBI. Retrying.", "notice";
          sleep 30;
          next;
        } else {
          # Got an empty result (this is what we're hoping for instead of the fault mentioned above)
          log_error "None of the " . scalar(@batch_query) . " ESTs found at NCBI using using query '" . $search_query . "'. Retrying, just in case.", "warning";
          sleep 5;
          next;
        }
      }

      # Got back an array of useful results. Figure out which of our current @term_set actually
      # got returned. Record ones that we didn't get back in @data_left.
      my ($not_found, $false_positives) = handle_search_results($fetch_results, @batch_query);

      if (scalar(@$false_positives)) {
        # TODO: Do more here?
        log_error "Found " . scalar(@$false_positives) . " false positives at GenBank.", "warning";
      }

      # Keep track of $not_found and to pass on to next segment
      push @not_found_by_acc, @$not_found;

      last; # Exit the retry 'til MAX_TRIES loop
    }
    if ($done > MAX_TRIES) {
      # ALL of the queries failed, so pass on all the ESTs being queried to the next section
      log_error "Couldn't fetch ESTs by ID after " . MAX_TRIES . " tries.", "warning";
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
      log_error "Didn't find EST " . $datum_obj->get_value . " anywhere!", "error";
    }
    log_error "Done.", "notice", "<";
  }
  log_error "Done.", "notice", "<";

  log_error "Done.", "notice", "<";
  return $success;
}

sub handle_search_results {
  my ($fetch_results, @ap_data) = @_;
  my @ests_not_found;
  my @unmatched_result_accs = $fetch_results->valueof();
  foreach my $ap_datum (@ap_data) {
    my ($applied_protocol, $direction, $datum) = @$ap_datum;
    my $datum_obj = $datum->get_object;

    if ($datum_obj->get_value() eq "AH001028") {
      #special case - we hope to never see this id again
      log_error "AH001028 (specifically) is a very strange GenBank entry that we cannot deal with. Skipping it.", "warning";
      next;
    }

    my ($genbank_feature) = grep { $datum_obj->get_value() eq $_->{'GBSeq_primary-accession'} } $fetch_results->valueof();
    if (!$genbank_feature) {
      push @ests_not_found, $ap_datum;
      next;
    }
    @unmatched_result_accs = grep { $datum_obj->get_value() ne $_->{'GBSeq_primary-accession'} } @unmatched_result_accs;

    # Pull out enough information from the GenBank record to create a Chado feature
    my ($seq_locus) = $genbank_feature->{'GBSeq_locus'};
    my ($genbank_gb) = grep { $_ =~ m/^gb\|/ } @{$genbank_feature->{'GBSeq_other-seqids'}->{'GBSeqid'}}; $genbank_gb =~ s/^gb\|//;
    my ($genbank_gi) = grep { $_ =~ m/^gi\|/ } @{$genbank_feature->{'GBSeq_other-seqids'}->{'GBSeqid'}}; $genbank_gi =~ s/^gi\|//;
    my $genbank_acc = $genbank_feature->{'GBSeq_primary-accession'};
    my ($est_name) = ($genbank_feature->{'GBSeq_definition'} =~ m/^(\S+)/);
    my $sequence = $genbank_feature->{'GBSeq_sequence'};
    my $seqlen = length($sequence);
    my $timeaccessioned = $genbank_feature->{'GBSeq_create-date'};
    my $timelastmodified = $genbank_feature->{'GBSeq_update-date'};
    my ($genus, $species) = ($genbank_feature->{'GBSeq_organism'} =~ m/^(\S+)\s+(.*)$/);

    if (!($seq_locus)) {      
      if ($genbank_gb) {
        log_error "dbEST id for " . $datum_obj->get_value() . " is not the primary identifier, but matches GenBank gb: $genbank_gb.", "warning";
      } elsif ($genbank_gi) {
        log_error "dbEST id for " . $datum_obj->get_value() . " is not the primary identifier, but matches GenBank gi: $genbank_gi.", "warning";
      } else {
        log_error "Found a record with matching accession for " . $datum_obj->get_value() . ", but no GBSeq_locus entry, so it's invalid", "error";
        push @ests_not_found, $ap_datum;
        next;
      }
    }

    # Create the Chado feature
    # First check to see if this feature has already been found (in say GFF)
    my $organism = new ModENCODE::Chado::Organism({ 'genus' => $genus, 'species' => $species });
    my $type = new ModENCODE::Chado::CVTerm({ 'name' => 'EST', 'cv' => new ModENCODE::Chado::CV({ 'name' => 'SO' }) });

    my $feature = ModENCODE::Cache::get_feature_by_uniquename_and_type($datum_obj->get_value(), $type);
    if ($feature) {
      log_error "Found already created feature " . $datum_obj->get_value() . " to represent EST feature.", "debug";
      if ($organism->get_id == $feature->get_object->get_organism_id) {
        log_error "  Using it because unique constraints are identical.", "debug";
        # Add DBXrefs
        $feature->get_object->add_dbxref(new ModENCODE::Chado::DBXref({
              'accession' => $genbank_gi,
              'db' => new ModENCODE::Chado::DB({
                  'name' => 'dbEST',
                  'description' => 'dbEST gi IDs',
                }),
            })
        );
        $feature->get_object->add_dbxref(new ModENCODE::Chado::DBXref({
              'accession' => $genbank_acc,
              'db' => new ModENCODE::Chado::DB({
                  'name' => 'GB',
                  'description' => 'GenBank',
                }),
            }),
        );
      } else {
        log_error "  Not using it because organisms (new: " .  $organism->get_object->to_string . ", existing: " .  $feature->get_object->get_organism(1)->to_string . ") differ.", "debug";
        $feature = undef;
      }
    }

    if (!$feature) {
      $feature = new ModENCODE::Chado::Feature({
          'name' => $est_name,
          'uniquename' => $genbank_acc,
          'residues' => $sequence,
          'seqlen' => $seqlen,
          'timeaccessioned' => $timeaccessioned,
          'timelastmodified' => $timelastmodified,
          'type' => $type,
          'organism' => $organism,
          'primary_dbxref' => new ModENCODE::Chado::DBXref({
              'accession' => $genbank_acc,
              'db' => new ModENCODE::Chado::DB({
                  'name' => 'GB',
                  'description' => 'GenBank',
                }),
            }),
          'dbxrefs' => [ new ModENCODE::Chado::DBXref({
              'accession' => $genbank_gi,
              'db' => new ModENCODE::Chado::DB({
                  'name' => 'dbEST',
                  'description' => 'dbEST gi IDs',
                }),
            }),
          ],
        });
    }

    # Add the feature to the datum
    $datum->get_object->add_feature($feature);
  }
  @unmatched_result_accs = map { $_->{'GBSeq_primary-accession'} } @unmatched_result_accs;

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

1;
