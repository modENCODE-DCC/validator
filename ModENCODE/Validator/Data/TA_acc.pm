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
use ModENCODE::Validator::TermSources;
use File::Temp;
use HTTP::Request::Common 'POST';
use LWP::UserAgent;
use XML::XPath;
#use XML::Xpath::XMLParser;

#use ModENCODE::Chado::XMLWriter;

my %soap_client                 :ATTR;
my %tmp_file                    :ATTR;


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
	#use Data::Dumper;
	#print STDERR Dumper($data);
    my $parser = XML::XPath->new(xml => $data);
    my $nodeset = $parser->findnodes('/wrapper/trace'); #each record is wrapped in a trace-identifier 
#    log_error "Parsed " . $nodeset->size . " trace records","notice";
    my @trace_data;
    foreach my $node ($nodeset->get_nodelist) {
        my $ti = $node->findvalue('./ti');

        my $trace_name = $node->findvalue('./trace_name');
        my $load_date = $node->findvalue('.//load_date');
	my $organism = $node->findvalue('.//species_code');
	my $sequence = $node->findvalue('.//sequence');
	my $seqlen = $node->findvalue('.//basecall_length');
	$organism = ucfirst(lc($organism));
	my ($genus, $species) = ($organism =~ m/^(\S+)\s+(.*)$/);
	
#       print "processed $count: $ti | $trace_name | $load_date | $genus $species \n";                              
        my $single_trace = { "trace_id" => $ti, "name" => $trace_name, "load_date" => $load_date, "genus" => $genus, "species" => $species, "seqlen" => $seqlen, "sequence" => $sequence };
        push @trace_data, $single_trace;
        $count++;
    }
    return \@trace_data;
}


sub validate {
  my ($self) = @_;
  my $success = 1;

  # Get out the Trace IDs we need to validate
  my @data_to_validate = @{$self->get_data()};

  my @data_left;
  log_error "Validating " . scalar(@data_to_validate) . " Traces...", "notice", ">";

  # Validate Traces against ones we've already seen and store locally
#  log_error "Fetching " . scalar(@data_to_validate) . " Traces from local modENCODE database...", "notice", ">";
#  my $parser = $self->get_parser_modencode();
#  my $term_source_validator = new ModENCODE::Validator::TermSources();

#  while (my $datum_hash = shift @data_to_validate) {
#    my $datum = $datum_hash->{'datum'}->clone();
#    my $id = $datum_hash->{'datum'}->get_value();
#    if (length($id)) {
#      my $feature = $parser->get_feature_by_genbank_id($id);  ##need to add a method for get_feature_by_trace_id($id)
#      if (!$feature) {
#        push @data_left, $datum_hash;
#        next;
#      }
##      if ($term_source_validator->check_and_update_features([$feature])) {
##        $xmlwriter->write_standalone_feature($feature);
##        my $placeholder_feature = new ModENCODE::Chado::Feature({ 'chadoxml_id' => $feature->get_chadoxml_id() });
#
##        $datum->add_feature($placeholder_feature);
#        $datum->add_feature($feature);
#        $datum_hash->{'merged_datum'} = $datum;
#        $datum_hash->{'is_valid'} = 1;
#      } else {
#        $success = 0;
#      }
#    }
#  }

#  @data_to_validate = @data_left;
#  @data_left = ();
#  log_error "Done (" . scalar(@data_to_validate) . " remaining).", "notice", "<";
  my $est_counter = 0;
  # Validate remaining Trace IDs against Trace Archive by primary ID
  if (scalar(@data_to_validate)) {
    log_error "Pulling down Trace information from Trace Archive by ID in batches of 200...", "notice", ">";
    my $trace_counter = 1;
    my @all_results;
    while (scalar(@data_to_validate)) {
      # Generate search query "est1,est2,est3,..."
      my @term_set;
      for (my $i = 0; $i < 200; $i++) {
        my $datum_hash = shift @data_to_validate;
        last unless $datum_hash;
        $est_counter++;
        push @term_set, $datum_hash if length($datum_hash->{'datum'}->get_value());
      }
      my $fetch_term = join(",", map { $_->{'datum'}->get_value() } @term_set);
      log_error "Fetching Traces from " . ($est_counter - scalar(@term_set)) . " to " . ($est_counter-1) . "...", "notice", "=";
      ModENCODE::ErrorHandler::set_logtype(ModENCODE::ErrorHandler::LOGGING_PREFIX_OFF);

      # Run query and get back the xml of the results                      :
      my $query = 'retrieve xml_info ' . $fetch_term;
      my $trace_xml;
      eval {
        $trace_xml = query_traceDB($query);
      };

      if (!$trace_xml)      {
        # Couldn't get anything useful back (bad network connection?). Wait 30 seconds and retry.
        log_error "Couldn't retrieve Traces by ID; got an unknown response from TA. Retrying.", "notice";
        unshift @data_to_validate, @term_set;
        sleep 30;
        next;
      }

      #parse the results into a resulting array
      my $data = parse_traceXML($trace_xml);

      log_error " Retrieved " . scalar(@$data) . " traces. Validating...", "notice", ".";

      ######################################################################################

      foreach my $datum_hash (@term_set) {
	      my $datum = $datum_hash->{'datum'}->clone();
      	my ($trace) = grep { $_->{'trace_id'} eq $datum->get_value() } @$data;
        
        if ($trace) {
          my $ti = $trace->{'trace_id'};
          my $trace_name = $trace->{'name'};
          my $load_date = $trace->{'load_date'};
	  my $species   = $trace->{'species'};
	  my $genus     = $trace->{'genus'};
	  my $sequence  = $trace->{'sequence'};
	  my $seqlen = $trace->{'seqlen'};
          #create the feature object
          my $feature = new ModENCODE::Chado::Feature({
              'name' => $trace_name,
              'uniquename' => $ti,
              'timeaccessioned' => $load_date,
	      'seqlen' => $seqlen,
	      'residues' => $sequence,
              'type' => new ModENCODE::Chado::CVTerm({
                'name' => 'TraceArchive_record',  ##this should be changed to trace_archive_record        
                'cv' => new ModENCODE::Chado::CV({ 'name' => 'modencode' })
                }),
              'organism' => new ModENCODE::Chado::Organism({
                  'genus' => $genus,
                  'species' => $species,
                }),
              'primary_dbxref' => new ModENCODE::Chado::DBXref({
                'accession' => $ti,
                'db' => new ModENCODE::Chado::DB({
                  'name' => 'TA',
                  'description' => 'TraceArchive',
                  }),
                }),
              'dbxrefs' => [ new ModENCODE::Chado::DBXref({
                'accession' => $ti,
                'db' => new ModENCODE::Chado::DB({
                  'name' => 'TA',
                  'description' => 'TraceArchive',
                  }),
                }),
              ],
          });
	  #print STDERR $feature;
          # Add the feature object to a copy of the datum for later merging
          $datum->add_feature($feature);
          $datum_hash->{'merged_datum'} = $datum;
          $datum_hash->{'is_valid'} = 1;
        } else {
          log_error "Couldn't find the Trace identified by " . $datum->get_value() . " in search results from NCBI.", "warning";
          push @data_left, $datum_hash;
        }
      }
      sleep 5; # Make no more than one request every 3 seconds (2 for flinching, Milo)
      log_error "Done.  " . scalar(@data_to_validate) . " to go...","notice";
      ModENCODE::ErrorHandler::set_logtype(ModENCODE::ErrorHandler::LOGGING_PREFIX_ON);
    }
    @data_to_validate = @data_left;
    @data_left = ();
    log_error "Done (" . scalar(@data_to_validate) . " trace IDs remaining).", "notice", "<";
  }

  log_error "Done.", "notice", "<";
  if (scalar(@data_to_validate)) {
    my $trace_list = "'" . join("', '", map { $_->{'datum'}->get_value() } @data_to_validate) . "'";
    log_error "Can't validate all traces. There is/are " . scalar(@data_to_validate) . " trace(s) that could not be validated. See previous errors.", "error";
    $success = 0;
  }

  return $success;
}

sub merge {
  my ($self, $datum, $applied_protocol) = @_;

  my $validated_datum = $self->get_datum($datum, $applied_protocol)->{'merged_datum'};


  return $validated_datum;
}


sub get_parser_modencode : PRIVATE {
  my ($self) = @_;
  my $parser = new ModENCODE::Parser::Chado({
      'dbname' => ModENCODE::Config::get_cfg()->val('databases modencode', 'dbname'),
      'host' => ModENCODE::Config::get_cfg()->val('databases modencode', 'host'),
      'port' => ModENCODE::Config::get_cfg()->val('databases modencode', 'port'),
      'username' => ModENCODE::Config::get_cfg()->val('databases modencode', 'username'),
      'password' => ModENCODE::Config::get_cfg()->val('databases modencode', 'password'),
      'caching' => 0,
    });
  $parser->set_no_relationships(1);
  return $parser;
}

1;
