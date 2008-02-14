package ModENCODE::Validator::Data::dbEST_gi;
use strict;
use base qw( ModENCODE::Validator::Data::Data );
use Class::Std;
use Carp qw(croak carp);
use SOAP::Lite;
use ModENCODE::Chado::Feature;
use ModENCODE::Chado::CVTerm;
use ModENCODE::Chado::CV;
use ModENCODE::Chado::Organism;
use ModENCODE::ErrorHandler qw(log_error);

my %soap_client                 :ATTR;

sub BUILD {
  my ($self, $ident, $args) = @_;
  $soap_client{$ident} = SOAP::Lite->service('http://www.ncbi.nlm.nih.gov/entrez/eutils/soap/eutils.wsdl');
  $soap_client{$ident}->serializer->envprefix('SOAP-ENV');
  $soap_client{$ident}->serializer->encprefix('SOAP-ENC');
  $soap_client{$ident}->serializer->soapversion('1.1');
}

sub validate {
  my ($self) = @_;
  my $success = 1;
  my @ids;
  foreach my $datum_hash (@{$self->get_data()}) {
    push @ids, $datum_hash->{'datum'}->get_value();
  }

  my $result = $soap_client{ident $self}->run_eFetch({
      'eFetchRequest' => {
        'db' => 'nucest',
        'id' => join(",", @ids),
        'tool' => 'modENCODE pipeline',
        'email' => 'yostinso@berkeleybop.org',
      }
    });

  foreach my $datum_hash (@{$self->get_data()}) {
    my $datum = $datum_hash->{'datum'}->clone();
    my $id = $datum->get_value();
    my $datum_success = 1;
    my $result_item;
    foreach my $gbseq (@{$result->{'GBSeq'}}) {
      my $found_id = grep { 'gi|' . $id eq $_ } @{$gbseq->{'GBSeq_other-seqids'}->{'GBSeqid'}};
      if ($found_id) {
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

      $datum->set_feature($feature);
      $datum_hash->{'merged_datum'} = $datum;
    }
    $datum_hash->{'is_valid'} = $datum_success;
  }
  return $success;
}

sub merge {
  my ($self, $datum) = @_;

  my ($validated_entry) = grep { $_->{'datum'}->equals($datum); } @{$self->get_data()};

  return $validated_entry->{'merged_datum'};
}

1;
