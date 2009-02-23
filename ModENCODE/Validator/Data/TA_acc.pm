package ModENCODE::Validator::Data::TA_acc;
=pod

=head1 NAME

ModENCODE::Validator::Data::TA_acc - Class for validating and updating
BIR-TAB L<Data|ModENCODE::Chado::Data> objects containing GenBank accessions for
Trace Archive IDs to include L<Features|ModENCODE::Chado::Feature> for those traces.

=head1 SYNOPSIS

This class is meant to be used to build a L<ModENCODE::Chado::Feature> object
(and associated L<CVTerms|ModENCODE::Chado::CVTerm> and
LOrganismDBXref|ModENCODE::Chado::Organism>s) for a provided GenBank TraceArchive
accession. TA information will potentially be fetched from a few different
sources, depending on availability; but more likely IDs will be verified and URLs provided. If the TA accession in question is already in the
local modENCODE Chado database (defined in the C<[databases modencode]> section of
the ini-file loaded by L<ModENCODE::Config>), then a feature will be created
from there. If it's unavailable in the modENCODE database, a search is run via a
http POST to the TraceArchive, and the Trace feature is built from the GenBank
dbEST record.

=head1 USAGE

The goal of using multiple sources is to reduce the impact on outside
repositories, since these resources are often under
load or are otherwise restricting connections. This also ends up vastly
increasing speed for large numbers of Traces that can be found in one of the
databases.  However, Traces will probably not previously be in the Chado database, 
and Flybase does not maintain this information, so it is likely all Traces
will need to be retrieved from the Trace Archive.


When given L<ModENCODE::Chado::Data> objects with values that are TA
accessions, this module first uses
L<ModENCODE::Parser::Chado/get_feature_by_genbank_id($genbank_id)> to fetch the
Trace from the modENCODE database, If these fail, 
all of the TA accessions left are grouped into batches of
40, and sent to the TraceArchive URL where they retrieve general information for each
matching trace in XML format.  Each trace is encased in a <trace></trace> element.  
IDs that don't have a matching record do not return anything (return blank), rather than
an empty trace element.  All of the trace nodes are parsed using L<XML::XPath>, 
with the id, name, and accession date extracted, and placed into an array.  Each
trace is scanned to make sure they actually match the Trace IDs being
searched for and aren't just fuzzy search results.

To use this validator in a standalone way:

  my $datum = new ModENCODE::Chado::Data({
    'value' => 'TRACEACCESSION'
  });
  my $validator = new ModENCODE::Validator::Data::TA_acc();
  $validator->add_datum($datum, $applied_protocol);
  if ($validator->validate()) {
    my $new_datum = $validator->merge($datum);
    print $new_datum->get_features()->[0]->get_name();
  }

Note that this class is not meant to be used directly, rather it is mean to be
used within L<ModENCODE::Validator::Data>.

=head1 PREWRITTEN FEATURES

=head1 FUNCTIONS

=over

=item validate()

Makes sure that all of the data added using L<add_datum($datum,
$applied_protocol)|ModENCODE::Validator::Data::Data/add_datum($datum,
$applied_protocol)> have values that exist as a TraceArchive accession in either
the local modENCODE database, FlyBase, or GenBank.

=item merge($datum, $applied_protocol)

Given an original L<datum|ModENCODE::Chado::Data> C<$datum>,
returns a copy of that datum with a newly attached feature based on an EST
record in either the local modENCODE database or TraceArchive for the value
in that C<$datum>.

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

Nicole Washington L<mailto:NLWashington@lbl.gov>, ModENCODE DCC
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
use File::Temp;
use HTTP::Request::Common 'POST';
use LWP::UserAgent;
use XML::XPath;
#use XML::Xpath::XMLParser;

#use ModENCODE::Chado::XMLWriter;

my %soap_client                 :ATTR;
my %tmp_file                    :ATTR;


# TODO: these should be changed to trace_archive_record once it's in SO
use constant TRACE_CV_NAME => "modencode";
use constant TRACE_CVTERM_NAME => "TraceArchive_record";

use constant MAX_TRIES => 2;
use constant TRACES_AT_ONCE => 200;


sub validate {
  my ($self) = @_;
  my $success = 1;

  
  log_error "Validating " . scalar($self->num_data) . " traces...", "notice", ">";

  # See if it's in the local instance already
  log_error "Checking local Chado database...", "notice", ">";
  foreach my $parse (
    ['modENCODE', $self->get_modencode_chado_parser(), [ 'TA' ]],
  ) {
    my ($parser_name, $parser, $dbnames) = @$parse;
    if (!$parser) {
      log_error "Can't check traces against the $parser_name database; skipping.", "warning";
      next;
    }
    while (my $ap_datum = $self->next_datum) {
      my ($applied_protocol, $direction, $datum) = @$ap_datum;

      my $datum_obj = $datum->get_object;
      my $accession = $datum_obj->get_value;

      my $feature = $parser->get_feature_by_dbs_and_accession($dbnames, $accession);
      next unless $feature;

      $self->remove_current_datum;
    }
    $self->rewind();
  }
  log_error "Done.", "notice", "<";


  log_error "Looking up " . $self->num_data . " traces in TA.", "notice", ">";
  # Pull any remaining data
  my @not_found_by_acc;
  while ($self->num_data) {
    # Get TRACES_AT_ONCE traces at a time and search at the TraceArchive
    my @batch_query;
    my $num_traces = 0;
    while (my $ap_datum = $self->next_datum) {
      push @batch_query, $ap_datum;
      $self->remove_current_datum; # This is the last chance this trace gets to be found
      last if (++$num_traces >= TRACES_AT_ONCE);
    }

    log_error "Fetching batch of " . scalar(@batch_query) . " traces.", "notice", ">";
    my $fetch_query = "retrieve xml_info " . join(",", map { $_->[2]->get_object->get_value } @batch_query);

    my $done = 0;
    while ($done++ < MAX_TRIES) {
      # TODO: Get from trace archive
      my $trace_xml;
      eval {
        $trace_xml = query_traceDB($fetch_query);
      };

      if (!$trace_xml) {
        # Couldn't get anything useful back (bad network connection?). Wait 30 seconds and retry.
        log_error "Couldn't retrieve traces by ID; got an unknown response from TraceArchive. Retrying in 30 seconds.", "notice";
        sleep 30;
        next;
      }

      my $fetch_results = parse_traceXML($trace_xml);
      log_error "Retrieved " . scalar(@$fetch_results) . " traces. Verifying.", "notice";

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
      log_error "Couldn't fetch traces after " . MAX_TRIES . " tries.", "warning";
      @not_found_by_acc = @batch_query;
    }
    # If we found everything, move on to the next batch of ESTs
    unless (scalar(@not_found_by_acc)) {
      sleep 5; # Make no more than one request every 3 seconds (2 for flinching, Milo)
      log_error "Done.", "notice", "<";
      next; # SUCCESS
    }
    log_error "Done.", "notice", "<";


    ###### ERROR - DIDN'T FIND ALL TRACES ######
    $success = 0;
    foreach my $missing_trace (@not_found_by_acc) {
      my $datum_obj = $missing_trace->[2]->get_object;
      log_error "Didn't find trace " . $datum_obj->get_value() . " in search results from NCBI.", "error";
    }
    log_error "Done.", "notice", "<";
  }
  log_error "Done.", "notice", "<";

  log_error "Done.", "notice", "<";
  return $success;
}

sub merge {
  my ($self, $datum, $applied_protocol) = @_;

  my $validated_datum = $self->get_datum($datum, $applied_protocol)->{'merged_datum'};


  return $validated_datum;
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

sub query_traceDB : PRIVATE {
    $ENV{'LANG'}='C';
    $ENV{'LC_ALL'}='C';
    my ($query) = @_;
    my $req = POST 'http://trace.ncbi.nlm.nih.gov/Traces/trace.cgi?cmd=raw', [query=>$query];
    my $res =  LWP::UserAgent->new->request($req);
#    my $res =  LWP::UserAgent->new->request($req, sub { print $_[0] });                          
    my $xml = '';
    if (!$res->is_success) {
	log_error "Couldn't connect to TRACE server\n", "error";
    } else {
	$xml = $res->content;
    }
    return $xml;
}

sub parse_traceXML : PRIVATE {
    my ($data) = @_;
    my $count = 0;
    $data = '<wrapper>' . $data . '</wrapper>';
    my $parser = XML::XPath->new(xml => $data);
    my $nodeset = $parser->findnodes('/wrapper/trace'); #each record is wrapped in a trace-identifier 
    log_error "Parsing " . $nodeset->size . " trace records", "debug", ">";
    my @trace_data;
    foreach my $node ($nodeset->get_nodelist) {
        my $ti = $node->findvalue('./ti');
        my $trace_name = $node->findvalue('./trace_name');
        my $load_date = $node->findvalue('.//load_date');
	my $organism = $node->findvalue('.//species_code');
	$organism = ucfirst(lc($organism));
	my ($genus, $species) = ($organism =~ m/^(\S+)\s+(.*)$/);
	
        my $single_trace = { "trace_id" => $ti, "name" => $trace_name, "load_date" => $load_date, "genus" => $genus, "species" => $species };
        push @trace_data, $single_trace;
        $count++;
    }
    log_error "Done.", "debug", "<";
    return \@trace_data;
}

sub handle_search_results {
  my ($fetch_results, @ap_data) = @_;

  my @traces_not_found;
  my @unmatched_result_accs = @$fetch_results;
  foreach my $ap_datum (@ap_data) {
    my ($applied_protocol, $direction, $datum) = @$ap_datum;
    my $datum_obj = $datum->get_object;

    my ($ta_feature) = grep { $datum_obj->get_value() eq $_->{'trace_id'} } @$fetch_results;
    if (!$ta_feature) {
      push @traces_not_found, $ap_datum;
      next;
    }
    @unmatched_result_accs = grep { $datum_obj->get_value ne $_->{'trace_id'} } @unmatched_result_accs;

    # Pull out enough information from TA record to create a Chado feature
    my $ti = $ta_feature->{'trace_id'};
    my $trace_name = $ta_feature->{'name'};
    my $load_date = $ta_feature->{'load_date'};
    my $species   = $ta_feature->{'species'};
    my $genus     = $ta_feature->{'genus'};

    # Create the Chado feature
    # First check to see if this feature has already been found (in say, GFF)
    my $organism = new ModENCODE::Chado::Organism({ 'genus' => $genus, 'species' => $species });
    my $type = new ModENCODE::Chado::CVTerm({ 'name' => TRACE_CVTERM_NAME, 'cv' => new ModENCODE::Chado::CV({ 'name' => TRACE_CV_NAME }) });

    my $feature = ModENCODE::Cache::get_feature_by_uniquename_and_type($datum_obj->get_value(), $type);
    if ($feature) {
      log_error "Found already created feature " . $datum_obj->get_value() . " to represent trace feature.", "debug";
      if ($organism->get_id == $feature->get_object->get_organism_id) {
        log_error "  Using it because unique constraints are identical.", "debug";
        # Add DBXref
        $feature->get_object->add_dbxref(new ModENCODE::Chado::DBXref({
              'accession' => $ti,
              'db' => new ModENCODE::Chado::DB({
                  'name' => 'TA',
                  'description' => 'TraceArchive',
                }),
            })
        );
      } else {
        log_error "  Not using it because organisms (new: " .  $organism->get_object->to_string . ", existing: " .  $feature->get_object->get_organism(1)->to_string . ") differ.", "debug";
        $feature = undef;
      }
    }

    if (!$feature) {
      $feature = new ModENCODE::Chado::Feature({
          'name' => $trace_name,
          'uniquename' => $ti,
          'timeaccessioned' => $load_date,
          'type' => $type,
          'organism' => $organism,
          'primary_dbxref' => new ModENCODE::Chado::DBXref({
              'accession' => $ti,
              'db' => new ModENCODE::Chado::DB({
                  'name' => 'TA',
                  'description' => 'TraceArchive',
                }),
            }),
        });
    }

    # Add the feature to the datum
    $datum->get_object->add_feature($feature);
  }
  @unmatched_result_accs = map { $_->{'trace_id'} } @unmatched_result_accs;

  return (\@traces_not_found, \@unmatched_result_accs);
}

1;
