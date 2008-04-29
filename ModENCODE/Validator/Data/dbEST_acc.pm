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
use ModENCODE::Parser::Chado;
use ModENCODE::ErrorHandler qw(log_error);
use File::Temp;
use ModENCODE::Chado::XMLWriter;

my %soap_client                 :ATTR;
my %tmp_file                    :ATTR;

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
  my @data_to_validate = @{$self->get_data()};
  my @data_left;

  log_error "Validating " . scalar(@data_to_validate) . " ESTs...", "notice", ">";

  my $root_dir = $0;
  $root_dir =~ s/[^\/]*$//;
  $root_dir = "./" unless $root_dir =~ /\//;
  my $tmp_file = new File::Temp(
    'TEMPLATE' => "dbEST_acc_ESTs_XXXX",
    'DIR' => $root_dir,
    'SUFFIX' => '.xml',
    'UNLINK' => 1,
  );
  my $xmlwriter = new ModENCODE::Chado::XMLWriter();
  $xmlwriter->set_output_handle($tmp_file);
  $xmlwriter->add_additional_xml_writer($xmlwriter);

  # Validate ESTs against ones we've already seen and store locally
  log_error "Fetching " . scalar(@data_to_validate) . " ESTs from local modENCODE database...", "notice", ">";
  my $parser = $self->get_parser_modencode();
  while (my $datum_hash = shift @data_to_validate) {
    my $datum = $datum_hash->{'datum'}->clone();
    my $id = $datum_hash->{'datum'}->get_value();
    if (length($id)) {
      my $feature = $parser->get_feature_by_genbank_id($id);
      if (!$feature) {
        push @data_left, $datum_hash;
        next;
      }
      $xmlwriter->write_standalone_feature($feature);
      my $placeholder_feature = new ModENCODE::Chado::Feature({ 'chadoxml_id' => $feature->get_chadoxml_id() });

      $datum->add_feature($placeholder_feature);
      $datum_hash->{'merged_datum'} = $datum;
      $datum_hash->{'is_valid'} = 1;
    }
  }

  @data_to_validate = @data_left;
  @data_left = ();
  log_error "Done (" . scalar(@data_to_validate) . " remaining).", "notice", "<";

  # Validate remaining ESTs against FlyBase
  if (scalar(@data_to_validate)) {
    log_error "Falling back to fetching remaining " . scalar(@data_to_validate) . " ESTs from FlyBase...", "notice", ">";
    $parser = $self->get_parser_flybase();
    my $i = 0;
    while (my $datum_hash = shift @data_to_validate) {
      my $datum = $datum_hash->{'datum'}->clone();
      my $id = $datum_hash->{'datum'}->get_value();
      if (length($id)) {
        $i++;
        my $feature = $parser->get_feature_by_genbank_id($id);
        if (!$feature) {
          push @data_left, $datum_hash;
          next;
        }
        $xmlwriter->write_standalone_feature($feature);
        my $placeholder_feature = new ModENCODE::Chado::Feature({ 'chadoxml_id' => $feature->get_chadoxml_id() });

        $datum->add_feature($placeholder_feature);
        $datum_hash->{'merged_datum'} = $datum;
        $datum_hash->{'is_valid'} = 1;
      }
    }
    @data_to_validate = @data_left;
    @data_left = ();
    log_error "Done (" . scalar(@data_to_validate) . " remaining).", "notice", "<";
  }

  if (scalar(@data_to_validate)) {
    log_error "Falling back to pulling down EST information from Genbank...", "notice", ">";

    my $est_counter = 1;
    my @all_results;
    while (scalar(@data_to_validate)) {
      # Generate search query "est1 OR est2 OR est3 OR ..."
      my @term_set;
      for (my $i = 0; $i < 40; $i++) {
        my $datum_hash = shift @data_to_validate;
        last unless $datum_hash;
        $est_counter++;
        push @term_set, $datum_hash if length($datum_hash->{'datum'}->get_value());
      }
      my $search_term = join(" OR ", map { $_->{'datum'}->get_value() } @term_set);
      log_error "Searching ESTs from " . ($est_counter - scalar(@term_set)) . " to " . ($est_counter-1) . ".", "notice";

      # Run query and get back the cookie that will let us fetch the result:
      my $search_results;
      eval {
        $search_results = $soap_client{ident $self}->run_eSearch({
            'eSearchRequest' => {
              'db' => 'nucest',
              'term' => $search_term,
              'tool' => 'modENCODE pipeline',
              'email' => 'yostinso@berkeleybop.org',
              'usehistory' => 'y',
              'retmax' => 400,
            }
          });
      };
      if (!$search_results) {
        # Couldn't get anything useful back (bad network connection?). Wait 30 seconds and retry.
        log_error "Couldn't retrieve EST by ID; got an unknown response from NCBI. Retrying.", "notice";
        unshift @data_to_validate, @term_set;
        sleep 30;
        next;
      }

      if ($search_results->fault) {
        # Got back a SOAP fault, which means our query got through but NCBI gave us junk back.
        # Wait 30 seconds and retry - this seems to just happen sometimes.
        log_error "Couldn't search for EST ID's; got response \"" . $search_results->faultstring . "\" from NCBI. Retrying.", "notice";
        unshift @data_to_validate, @term_set;
        sleep 30;
        next;
      }
      # Pull out the cookie and query key that will allow us to actually fetch the results proper
      $search_results->match('/Envelope/Body/eSearchResult/WebEnv');
      my $webenv = $search_results->valueof();
      $search_results->match('/Envelope/Body/eSearchResult/QueryKey');
      my $querykey = $search_results->valueof();

      # If we didn't get a valid query key or cookie, something screwy happened without a fault.
      # Wait 30 seconds and retry.
      if (!length($querykey) || !length($webenv)) {
        log_error "Couldn't get a search cookie when searching for ESTs; got an unexpected response from NCBI. Retrying.", "notice";
        unshift @data_to_validate, @term_set;
        sleep 30;
        next;
      }

      ######################################################################################

      # Okay, got a valid query key and cookie, go ahead and fetch the actual results.
      my $fetch_results;
      eval {
        $fetch_results = $soap_client{ident $self}->run_eFetch({
            'eFetchRequest' => {
              'db' => 'nucest',
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
        log_error "Couldn't retrieve EST by ID; got an unknown response from NCBI. Retrying.", "notice";
        unshift @data_to_validate, @term_set;
        sleep 30;
        next;
      }

      if ($fetch_results->fault) {
        my $faultstring = $fetch_results->faultstring;
        # Got back a SOAP fault, which means our query got through but NCBI gave us junk back.
        # Sadly, this is also what happens when there are no results. The standard Eutils response 
        # is "Error: download dataset is empty", which apparently translates to a SOAP fault. Since
        # the search itself worked, we'll assume that NCBI didn't just die and that what we're really
        # seeing is a lack of results, in which case push all of the ESTs in this package back on the
        # stack.
        push @data_left, @term_set;
        sleep 5;
        next;
      }
      $fetch_results->match('/Envelope/Body/eFetchResult/GBSet/GBSeq');
      if (!length($fetch_results->valueof())) {
        if (!$fetch_results->match('/Envelope/Body/eFetchResult')) {
          # No eFetchResult result at all, which means we got back junk. Wait 30 seconds and retry.
          log_error "Couldn't retrieve EST by ID; got an unknown response from NCBI. Retrying.", "notice";
          unshift @data_to_validate, @term_set;
          sleep 30;
          next;
        } else {
          # Got an empty result (this is what we're hoping for instead of the fault mentioned above)
          log_error "Couldn't find any ESTs using when searching for '" . $search_term . "' at NCBI.", "warning";
          push @data_left, @term_set;
          sleep 5;
          next;
        }
      }

      # Got back an array of useful results. Figure out which of our current @term_set actually
      # got returned. Record ones that we didn't get back in @data_left.
      foreach my $datum_hash (@term_set) {
        my $datum = $datum_hash->{'datum'}->clone();
        my ($genbank_feature) = grep { $datum->get_value() eq $_->{'GBSeq_primary-accession'} } $fetch_results->valueof();
        if ($genbank_feature) {
          # Pull out enough information from the GenBank record to create a Chado feature
          my ($dbest_id) = grep { $_ =~ m/^gnl\|dbEST\|/ } @{$genbank_feature->{'GBSeq_other-seqids'}->{'GBSeqid'}}; $dbest_id =~ s/^gnl\|dbEST\|//;
          my ($genbank_gi) = grep { $_ =~ m/^gi\|/ } @{$genbank_feature->{'GBSeq_other-seqids'}->{'GBSeqid'}}; $genbank_gi =~ s/^gi\|//;
          my $genbank_acc = $genbank_feature->{'GBSeq_primary-accession'};
          my ($est_name) = ($genbank_feature->{'GBSeq_definition'} =~ m/^(\S+)/);
          my $sequence = $genbank_feature->{'GBSeq_sequence'};
          my $seqlen = length($sequence);
          my $timeaccessioned = $genbank_feature->{'GBSeq_create-date'};
          my $timelastmodified = $genbank_feature->{'GBSeq_update-date'};
          my ($genus, $species) = ($genbank_feature->{'GBSeq_organism'} =~ m/^(\S+)\s+(.*)$/);

          # Create the feature object
          my $feature = new ModENCODE::Chado::Feature({
              'name' => $est_name,
              'uniquename' => $genbank_acc,
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
              'primary_dbxref' => new ModENCODE::Chado::DBXref({
                  'accession' => $genbank_acc,
                  'db' => new ModENCODE::Chado::DB({
                      'name' => 'GB',
                      'description' => 'GenBank',
                    }),
                }),
              'dbxrefs' => [ new ModENCODE::Chado::DBXref({
                  'accession' => $dbest_id,
                  'db' => new ModENCODE::Chado::DB({
                      'name' => 'dbEST',
                      'description' => 'dbEST gi IDs',
                    }),
                }),
              ],
            });

          # Add the feature object to a copy of the datum for later merging
          $datum->add_feature($feature);
          $datum_hash->{'merged_datum'} = $datum;
          $datum_hash->{'is_valid'} = 1;
        } else {
          log_error "Couldn't find the EST identified by '" . $datum->get_value() . "' in search results from NCBI.", "warning";
          push @data_left, $datum_hash;
        }
      }

      sleep 5; # Make no more than one request every 3 seconds (2 for flinching, Milo)
    }
    @data_to_validate = @data_left;
    @data_left = ();
    log_error "Done (" . scalar(@data_to_validate) . " remaining).", "notice", "<";
  }
  log_error "Done.", "notice", "<";
  if (scalar(@data_to_validate)) {
    my $est_list = "'" . join("', '", map { $_->{'datum'}->get_value() } @data_to_validate) . "'";
    log_error "Can't validate all ESTs. There is/are " . scalar(@data_to_validate) . " EST(s) that could not be validated. See previous errors.", "error";
    $success = 0;
  }

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

sub get_parser_flybase : PRIVATE {
  my ($self) = @_;
  my $parser = new ModENCODE::Parser::Chado({
      'dbname' => ModENCODE::Config::get_cfg()->val('databases flybase', 'dbname'),
      'host' => ModENCODE::Config::get_cfg()->val('databases flybase', 'host'),
      'port' => ModENCODE::Config::get_cfg()->val('databases flybase', 'port'),
      'username' => ModENCODE::Config::get_cfg()->val('databases flybase', 'username'),
      'password' => ModENCODE::Config::get_cfg()->val('databases flybase', 'password'),
      'caching' => 0,
    });
  $parser->set_no_relationships(1);
  return $parser;
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
