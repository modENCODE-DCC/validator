package ModENCODE::Validator::Data::dbEST_acc;
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
use ModENCODE::Chado::AnalysisFeature;
use ModENCODE::Chado::Analysis;
use ModENCODE::Chado::FeatureRelationship;
use ModENCODE::Chado::FeatureLoc;
use ModENCODE::ErrorHandler qw(log_error);

my %soap_client                 :ATTR;

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
  log_error "Pulling down EST information from Genbank...", "notice", "=";
  my $success = 1;
  my @ids;
  foreach my $datum_hash (@{$self->get_data()}) {
    push @ids, $datum_hash->{'datum'}->get_value();
  }

  my @all_results;
  for (my $i = 0; $i < scalar(@ids) + 400; $i += 400) {
    my $term = $ids[$i];
    my $iplus = (scalar(@ids)-$i-1 < 400) ? scalar(@ids) : 400;
    $term = join(" OR ", @ids[$i..$i+$iplus]);
    my $results = $soap_client{ident $self}->run_eSearch({
        'eSearchRequest' => {
          'db' => 'nucest',
          'term' => $term,
          'tool' => 'modENCODE pipeline',
          'email' => 'yostinso@berkeleybop.org',
          'usehistory' => 'y',
          'retmax' => 1000,
        }
      }) ;

    $results->match('/Envelope/Body/Fault/faultstring/');
    my $faultstring = $results->valueof();
    if ($faultstring) {
      log_error "Couldn't search for EST ID's; got response \"$faultstring\" from NCBI.", "error";
      $success = 0;
      next;
    }
    $results->match('/Envelope/Body/eSearchResult/WebEnv');
    my $webenv = $results->valueof();
    $results->match('/Envelope/Body/eSearchResult/QueryKey');
    my $querykey = $results->valueof();

    my $fetch_results = $soap_client{ident $self}->run_eFetch({
        'eFetchRequest' => {
          'db' => 'nucest',
          'WebEnv' => $webenv,
          'query_key' => $querykey,
          'tool' => 'modENCODE pipeline',
          'email' => 'yostinso@berkeleybop.org',
          'retmax' => 1000,
        }
      });

    $results->match('/Envelope/Body/Fault/faultstring/');
    $faultstring = $results->valueof();
    if ($faultstring) {
      log_error "Couldn't retrieve EST by ID, even though search was successful; got response \"$faultstring\" from NCBI.", "error";
      $success = 0;
      next;
    }
    $fetch_results->match('/Envelope/Body/eFetchResult/GBSet/GBSeq');
    push @all_results, $fetch_results->valueof();
    sleep 3; # Make no more than one request every 3 seconds
  }

  foreach my $datum_hash (@{$self->get_data()}) {
    my $datum = $datum_hash->{'datum'}->clone();
    my $id = $datum->get_value();
    my $datum_success = 1;
    my $result_item;
    foreach my $gbseq (@all_results) {
      if ($id eq $gbseq->{'GBSeq_primary-accession'}) {
          $result_item = $gbseq;
        }
      }
      if (!$result_item) {
        log_error "Couldn't fetch the EST identified by $id from NCBI.";
        $success = 0;
        $datum_success = 0;
      } else {

        # Extract Chado feature information from the SOAP EFetch result
        my ($dbest_id) = grep { $_ =~ m/^gnl\|dbEST\|/ } @{$result_item->{'GBSeq_other-seqids'}->{'GBSeqid'}}; $dbest_id =~ s/^gnl\|dbEST\|//;
        my ($genbank_gi) = grep { $_ =~ m/^gi\|/ } @{$result_item->{'GBSeq_other-seqids'}->{'GBSeqid'}}; $genbank_gi =~ s/^gi\|//;
        my $genbank_acc = $result_item->{'GBSeq_primary-accession'};
        my ($est_name) = ($result_item->{'GBSeq_definition'} =~ m/^(\S+)/);
        my $sequence = $result_item->{'GBSeq_sequence'};
        my $seqlen = length($sequence);

        my $timeaccessioned = $result_item->{'GBSeq_create-date'};
        my $timelastmodified = $result_item->{'GBSeq_update-date'};

        my ($genus, $species) = ($result_item->{'GBSeq_organism'} =~ m/^(\S+)\s+(.*)$/);

        # Create the feature object
        my $feature = new ModENCODE::Chado::Feature({
            'name' => $est_name,
            'uniquename' => 'dbest:' . $dbest_id,
            'residues' => $sequence,
            'seqlen' => $seqlen,
            'timeaccessioned' => $timeaccessioned,
            'timelastmodified' => $timelastmodified,
            'type' => new ModENCODE::Chado::CVTerm({
                'name' => 'EST',
                'cv' => new ModENCODE::Chado::CV({ 'name' => 'SO' })
              }),
            'organism' => new ModENCODE::Chado::Organism({
                'genus' => $genus,
                'species' => $species,
              }),
          });

        $datum->add_feature($feature);
        $datum_hash->{'merged_datum'} = $datum;
      }
      $datum_hash->{'is_valid'} = $datum_success;
    }
    log_error "Done.\n", "notice", ".";
    return $success;
}

sub merge {
  my ($self, $datum, $applied_protocol) = @_;

  my $validated_datum = $self->get_datum($datum, $applied_protocol)->{'merged_datum'};

  # If there's a GFF attached to this particular protocol, update any entries referencing this EST
  if (scalar(@{$validated_datum->get_features()})) {
    my $gff_validator = $self->get_data_validator()->get_validators()->{'modencode:GFF3'};
    if ($gff_validator) {
      foreach my $other_datum (@{$applied_protocol->get_input_data()}, @{$applied_protocol->get_output_data()}) {
        if (
          $other_datum->get_type()->get_name() eq "GFF3" && 
          ModENCODE::Config::get_cvhandler()->cvname_has_synonym($other_datum->get_type()->get_cv()->get_name(), "modencode")
        ) {
          if (defined($other_datum->get_value()) && length($other_datum->get_value())) {
            my $gff_feature = $gff_validator->get_feature_by_id_from_file(
              $validated_datum->get_value(),
              $other_datum->get_value()
            );
            if ($gff_feature) {
              # Update the GFF feature to look like this feature (but don't break any links
              # it may have to other features in the GFF, then return the updated feature as
              # part of the validated_datum
              croak "Unable to continue; the validated dbEST_acc datum " . $validated_datum->to_string() . " has more than one associated feature!" if (scalar(@{$validated_datum->get_features()}) > 1);
              $gff_feature->mimic($validated_datum->get_features()->[0]);
              $validated_datum->set_features( [$gff_feature] );
            }
          }
        }
      }
    }
  }
  return $validated_datum;
}

1;
