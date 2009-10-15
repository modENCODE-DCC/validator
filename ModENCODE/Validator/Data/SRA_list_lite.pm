package ModENCODE::Validator::Data::SRA_list_lite;
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
  log_error "Validating presence of " . $self->num_data . " lists of SRA submission(s).", "notice", ">";
  
  my %missing_accessions;
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

    log_error "Checking for " . $self->num_data . " SRA accession lists already in the $parser_name database...", "notice", ">";
    while (my $ap_datum = $self->next_datum) {
      my ($applied_protocol, $direction, $datum) = @$ap_datum;

      my $datum_obj = $datum->get_object;

      my @accessions = split(/;/, $datum_obj->get_value);
      
      my @missing_accessions;
      foreach my $accession (@accessions) {
        if (!length($accession)) {
          log_error "Empty value for SRA accession in column " . $datum_obj->get_heading . " [" . $datum_obj->get_name . "].", "warning";
          $self->remove_current_datum;
          next;
        }

        my $feature = $parser->get_feature_by_genbank_id($accession);
        unless ($feature) {
          push @missing_accessions, $accession;
          next;
        }

        my $cvterm = $feature->get_object->get_type(1)->get_name;
        my $cv = $feature->get_object->get_type(1)->get_cv(1)->get_name;
        my $canonical_cvname = ModENCODE::Config::get_cvhandler()->get_cv_by_name($cv)->{'names'}->[0];

        if ($cvterm ne "SRA_record") {
          log_error "Found a feature in $parser_name, but it is of type '$cv:$cvterm', not 'ME:SRA_record'. Not using it.", "warning";
          push @missing_accessions, $accession;
          next;
        }
        if ($canonical_cvname ne "modencode-helper") {
          # TODO: Use this and update the CV type?
          log_error "Found a feature in $parser_name, but it is of type '$cv:$cvterm', not 'SO:EST'. Not using it.", "warning";
          push @missing_accessions, $accession;
          next;
        }
      
        # If we found it, don't need to keep trying to validate it
        $datum->get_object->add_feature($feature);
      }
      if (scalar(@missing_accessions) == 0) {
        # Found all of the accessions, no need to look later
        $self->remove_current_datum;
      } else {
        $missing_accessions{$datum->get_id} = \@missing_accessions;
      }
    }
    log_error "Done.", "notice", "<";
    #log_error "Done; " . scalar(@missing_accessions) . " lists of accessions still to be found.", "notice", "<";

    $self->rewind();
  }
  log_error "Done.", "notice", "<";

  unless ($self->num_data) {
    log_error "Done.", "notice", "<";
    return $success;
  }

  # Validate remaining ESTs against GenBank by primary ID
  log_error "Looking up " . scalar(keys(%missing_accessions)) . " partial lists of accessions in SRA " , "notice", ">";

  my @not_found_by_acc;
  while ($self->num_data) {
    # Get 40 SRA records at a time and search for them at NCBI
    my $num_ests = 0;
    while (my $ap_datum = $self->next_datum) {
      $self->remove_current_datum; # This is this datum's last chance
      my ($applied_protocol, $direction, $datum) = @$ap_datum;
      my @accessions = @{$missing_accessions{$datum->get_id}};
      my $fetch_query = join(",", @accessions);
      if (scalar(@accessions) < 10) {
        log_error ("Fetching SRA ids: " .  $fetch_query . ".", "notice", ">");
      } else {
        log_error "Fetching batch of " . scalar(@accessions) . " SRA accessions.", "notice", ">";
      }

      my $done = 0;

      # Do we need to fall back to searching because we couldn't find by accession?
      while ($done++ < MAX_TRIES) {
        log_error "Searching for remaining batch of " . scalar(@accessions) . " SRA accessions.", "notice";

        # Run query (est1,est2,...) and get back the cookie that will let us fetch the result:
        my $search_query = join(" OR ", @accessions);
        my $fetch_results = $search_query;
        # TODO
        my ($not_found, $false_positives) = handle_summary_results($fetch_results, $datum, @accessions);


        # Keep track of $not_found and to pass on to next segment
        push @not_found_by_acc, @$not_found;

        last; # Exit the retry 'til MAX_TRIES loop
      }
      if ($done > MAX_TRIES) {
        # ALL of the queries failed, so pass on all the ESTs being queried to the next section
        log_error "Couldn't fetch SRA accessions by ID after " . MAX_TRIES . " tries.", "warning";
        @not_found_by_acc = @accessions;
      }
      # If we found everything, move on to the next batch of ESTs
      unless (scalar(@not_found_by_acc)) {
        sleep 5; # Make no more than one request every 3 seconds (2 for flinching, Milo)
        log_error "Done.", "notice", "<";
        next; # SUCCESS
      }
    }
    log_error "Done.", "notice", "<";

    ###### ERROR - DIDN'T FIND ALL ESTS ######
    foreach my $missing_est (@not_found_by_acc) {
      $success = 0;
      log_error "Didn't find accession " . $missing_est . " anywhere!", "error";
    }
    log_error "Done.", "notice", "<";
  }
  log_error "Done.", "notice", "<";

  log_error "Done.", "notice", "<";
  return $success;
}


sub handle_summary_results {
  my ($fetch_results, $datum, @accessions) = @_;
  my @ests_not_found;
  my @unmatched_result_accs = @accessions;
#  my $acc_num = 0;
  foreach my $genbank_acc (@accessions) {

    my $url = "http://www.ncbi.nlm.nih.gov/sites/entrez?db=sra&report=full";
    if ($genbank_acc =~ /^SR[AXRS]\d+/) {
#        $acc_num++;
#        if ($acc_num % 40 == 0) {
#          log_error "Created $acc_num attributes.", "notice";
#        }
	my $sra_id = $genbank_acc;
	$sra_id =~ s/\.\S+//;  #can find individual reads this way, need to use the full read set
	$url .= "&term=" . $sra_id;
	$datum->get_object->add_attribute(new ModENCODE::Chado::DatumAttribute({
	    'value' => $url,
	    'type' => new ModENCODE::Chado::CVTerm({'name' => 'anyURI', 'cv' => new ModENCODE::Chado::CV({'name' => 'xsd'})}),
	    'name' => $genbank_acc,
	    'heading' => 'data_url',
	    'datum' => $datum,
	 })
	);
    } else {
	log_error "You do not have a valid SRA id", "error";
	push @ests_not_found, $genbank_acc;
    }
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
