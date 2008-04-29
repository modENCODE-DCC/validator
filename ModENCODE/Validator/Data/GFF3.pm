package ModENCODE::Validator::Data::GFF3;
use strict;
use base qw( ModENCODE::Validator::Data::Data );
use Class::Std;
use Data::Dumper;
use Carp qw(croak carp);
use SOAP::Lite;
use Bio::FeatureIO::gff_modencode;
use ModENCODE::Chado::Feature;
use ModENCODE::Chado::CVTerm;
use ModENCODE::Chado::CV;
use ModENCODE::Chado::Organism;
use ModENCODE::Chado::AnalysisFeature;
use ModENCODE::Chado::Analysis;
use ModENCODE::Chado::FeatureRelationship;
use ModENCODE::Chado::FeatureLoc;
use ModENCODE::ErrorHandler qw(log_error);
use ModENCODE::Validator::TermSources;
use File::Temp;
use ModENCODE::Chado::XMLWriter;

my %cached_gff_features         :ATTR( :default<{}> );
my %features_by_uniquename      :ATTR( :default<{}> );

sub validate {
  my ($self) = @_;
  log_error "Parsing attached GFF3 files.", "notice", ">";
  my $success = 1;

  my $root_dir = $0;
  $root_dir =~ s/[^\/]*$//;
  $root_dir = "./" unless $root_dir =~ /\//;
  my $tmp_file = new File::Temp(
    'TEMPLATE' => "GFF3_XXXX",
    'DIR' => $root_dir,
    'SUFFIX' => '.xml',
    'UNLINK' => 1,
  );

  my $xmlwriter = new ModENCODE::Chado::XMLWriter();
  $xmlwriter->set_output_handle($tmp_file);
  $xmlwriter->add_additional_xml_writer($xmlwriter);
  my $term_source_validator = new ModENCODE::Validator::TermSources();

  my %features_by_id;
  foreach my $datum_hash (@{$self->get_data()}) {
    my $datum = $datum_hash->{'datum'}->clone();
    my $applied_protocol = $datum_hash->{'applied_protocol'};
    my $gff_file = $datum->get_value();
    next unless length($gff_file);
    if (!$cached_gff_features{ident $self}->{$gff_file}) {
      if (!-r $gff_file) {
        log_error "Cannot read GFF file '$gff_file'.";
        $success = 0;
        next;
      }
      log_error "Parsing GFF file " . $gff_file . "...", "notice", ">";
      unless (open GFF, $gff_file) {
        log_error "Cannot open GFF file '$gff_file' for reading.";
        $success = 0;
        next;
      }
      my $analysis = new ModENCODE::Chado::Analysis({
          'name' => $applied_protocol->get_protocol()->get_name(),
          'program' => $applied_protocol->get_protocol()->get_name(),
          'programversion' => $applied_protocol->get_protocol()->get_version(),
        });
      my $gffio = new Bio::FeatureIO(-fh => \*GFF, -format => 'gff_modencode', -version => 3);
      while (my @group_features = $gffio->next_feature_group()) {
        foreach my $top_level_feature (@group_features) {
          # These all get cached in features_by_id and features_by_uniquename
          my $feature = $self->gff_feature_to_chado_features($gffio, $top_level_feature, $analysis, \%features_by_id);
          if ($feature == -1) {
            $success = 0;
            next;
          }
          if ($feature) {
            if ($term_source_validator->check_and_update_features([$feature])) {
              $xmlwriter->write_standalone_feature($feature);
              my $placeholder_feature = new ModENCODE::Chado::Feature({ 'chadoxml_id' => $feature->get_chadoxml_id() });

              $datum->add_feature($placeholder_feature);
            } else {
              $success = 0;
            }
          }
          foreach my $key (keys(%features_by_id)) {
            my $feature = $features_by_id{$key};
            if ($feature && $feature->get_chadoxml_id()) {
              $features_by_id{$key} = new ModENCODE::Chado::Feature({ 'chadoxml_id' => $feature->get_chadoxml_id() });
            }
          }
        }
      }
      $cached_gff_features{ident $self}->{$gff_file} = \%features_by_id;
      close GFF;
      log_error "Done.\n", "notice", "<";
    }

    $datum_hash->{'merged_datum'} = $datum;
  }
  log_error "Done.", "notice", "<";
  $features_by_uniquename{ident $self} = {};
  return $success;
}

sub get_feature_by_id_from_file {
  my ($self, $id, $gff_file) = @_;
  if ($cached_gff_features{ident $self}->{$gff_file}) {
    return $cached_gff_features{ident $self}->{$gff_file}->{$id};
  }
  return undef;
}

sub gff_feature_to_chado_features : PRIVATE {
  my ($self, $gff_io, $gff_obj, $analysis, $features_by_id) = @_;

  my $gff_obj_id;
  if (
    defined($gff_obj->get_Annotations('ID')) && 
    defined(($gff_obj->get_Annotations('ID'))[0]) && 
    length(($gff_obj->get_Annotations('ID'))[0]->value())) {
    $gff_obj_id = ($gff_obj->get_Annotations('ID'))[0]->value();
  }

  # Deal with typing the sequence region
  if ($gff_obj->seq_id() eq $gff_io->sequence_region($gff_obj->seq_id()) && 
    defined($gff_obj_id) && $gff_obj_id eq $gff_io->seq_region($gff_obj->seq_id())->seq_id() &&
    length($gff_obj->type())) {
    # If we have a feature with the same ID as the seqregion, then assign its type to
    # the seqregion, instead of relying on the default "region"
    my $type = new Bio::Annotation::OntologyTerm();
    $gff_io->seq_region($gff_obj->seq_id())->type->name($gff_io->seq_region()->type()->name());
  }

  my $this_seq_region = $gff_io->sequence_region($gff_obj->seq_id());
  my $this_seq_region_feature = $features_by_id->{$this_seq_region->seq_id()};
  if (!$this_seq_region) {
    $this_seq_region = new ModENCODE::Chado::Feature({
        'uniquename' => $this_seq_region->seq_id(),
        'type' => new ModENCODE::Chado::CVTerm({
            'name' => $this_seq_region->type()->name(),
            'cv' => new ModENCODE::Chado::CV({ 
                'name' => 'SO',
              }),
          }),
      });
    $features_by_id->{$this_seq_region->seq_id()} = $this_seq_region_feature;
  }

  # Build this feature
  my ($feature_start, $feature_end) = ($gff_obj->location()->start(), $gff_obj->location()->end());

  if ($feature_start > $feature_end) {
    $_ = $feature_start;
    $feature_start = $feature_end;
    $feature_end = $_;
  }
  my $name = $gff_obj->name() || $gff_obj_id || "gff_obj_" . $gff_obj->type()->name() . "/$feature_start,$feature_end";

  my $gff_id = ($gff_obj->get_Annotations('ID'))[0] || ident($gff_obj);

  my $uniquename = $gff_id . ":gff_obj_" . $gff_obj->type()->name() . "/$feature_start,$feature_end";
  $uniquename .= ";strand=" . $gff_obj->strand() if defined($gff_obj->strand());
  $uniquename .= ";score=" . $gff_obj->score() if defined($gff_obj->score());
  $uniquename .= ";phase=" . $gff_obj->phase() if defined($gff_obj->phase());
  $uniquename .= ";on_chr=" . $gff_obj->seq_id();

  my $feature = $features_by_uniquename{ident $self}->{$uniquename};
  if (!$feature) {
    my $organism = new ModENCODE::Chado::Organism({
        'genus' => ($this_seq_region->get_Annotations('Organism_Genus'))[0],
        'species' => ($this_seq_region->get_Annotations('Organism_Species'))[0],
      });

    my $type = new ModENCODE::Chado::CVTerm({
        'name' => $gff_obj->type()->name(),
        'cv' => new ModENCODE::Chado::CV({ 'name' => 'SO' }),
      });

    my $primary_location;
   
    if (defined($feature_start) || defined($feature_end)) {
      $primary_location = new ModENCODE::Chado::FeatureLoc({ # vs. chromosome
          'rank' => 1,
          'srcfeature' => $this_seq_region_feature,
          'fmin' => $feature_start,
          'fmax' => $feature_end,
          'strand' => ($gff_obj->strand() eq '-' ? -1 : 1),
          'phase' => ($gff_obj->phase() eq '.' ? 0 : $gff_obj->phase()),
        });
    }


    ##########################################
    # If the Target attribute is used, create a placeholder feature for it
    my $target_location;
    my ($target) = $gff_obj->annotation()->get_Annotations("Target");
    if ($target) {
      # This will later be replaced with:
      #  a link to a feature from the SDRF
      #  a link to a feature in the final structure
      my ($target_start, $target_end, $target_name) = ($target->start(), $target->end(), $target->target_id()) if $target;
      if ($target_start > $target_end) {
        $_ = $target_start;
        $target_start = $target_end;
        $target_end = $_;
      }

      # Create the target feature or get it if already created
      my $target_feature = $features_by_id->{$target_name};
      if (!$target_feature) {
        $uniquename .= ";hit_from_" . $target_name . "($target_start,$target_end)";
        $uniquename .= "_by_analysis_" . $analysis->get_program() . ":" . $analysis->get_programversion();
        # Target features are just placeholders, so only have a name
        $target_feature = new ModENCODE::Chado::Feature({
            'name' => $target_name,
          });
        my $analysisfeature = new ModENCODE::Chado::AnalysisFeature({
            'feature' => $target_feature,
            'analysis' => $analysis,
          });
        if ($gff_obj->score()) {
          my $rawscore = $gff_obj->score()->value();
          $rawscore = undef if ($rawscore eq '.' || $rawscore eq '');
          $analysisfeature->set_rawscore($rawscore);
        }
        $target_feature->add_analysisfeature($analysisfeature);
        $features_by_id->{$target_name} = $target_feature;
      }

      $target_location = new ModENCODE::Chado::FeatureLoc({ # vs. target/est
          'rank' => 0,
          'srcfeature' => $target_feature,
          'fmin' => $target_start,
          'fmax' => $target_end,
        });
    }
    ##########################################

    $feature = new ModENCODE::Chado::Feature({
        'name' => $name,
        'organism' => $organism,
        'uniquename' => $uniquename,
        'type' => $type,
      });
    $feature->add_location($primary_location) if $primary_location;
    if (defined($gff_obj_id)) {
      my $feature_by_id = $features_by_id->{$gff_obj_id};
      if ($feature_by_id) {
        # If we've actually seen this feature before, use the old version
        # (assuming the locations don't conflict!)
        if (scalar(@{$feature_by_id->get_locations()})) {
          if ($primary_location && !scalar(grep { $primary_location->equals($_) } @{$feature_by_id->get_locations()})) {
            log_error "Mismatch between feature locations in GFF files with the same IDs for ID=$gff_obj_id.";
            return -1;
          }
        }
        $feature = $feature_by_id;
      }
      $features_by_id->{$gff_obj_id} = $feature;
    }
    $features_by_uniquename{ident $self}->{$uniquename} = $feature;
    # Add the hit to the target if any; this is also how the target_feature is tied in (srcfeature_id)
    if ($target_location) {
      # Add the location (and thus the target_feature, since it's the srcfeature_id)
      $feature->add_location($target_location) if ($target_location);
      # Make this an analysisfeature
      $feature->set_is_analysis(1);
      my $analysisfeature = new ModENCODE::Chado::AnalysisFeature({
          'feature' => $feature,
          'analysis' => $analysis,
        });
      if ($gff_obj->score()) {
        my $rawscore = $gff_obj->score()->value();
        $rawscore = undef if ($rawscore eq '.' || $rawscore eq '');
        $analysisfeature->set_rawscore($rawscore);
      }
      $feature->add_analysisfeature($analysisfeature);
    }
  }
  
  my @child_gff_features = $gff_obj->get_SeqFeatures();
  if (scalar(@child_gff_features)) {
    # Has children
    my $rank = 0;
    foreach my $child_gff_obj ($gff_obj->get_SeqFeatures()) {
      my $child_feature = $self->gff_feature_to_chado_features($gff_io, $child_gff_obj, $analysis, $features_by_id);
      if ($child_feature == -1) {
        return -1;
        next;
      }
      my $relationship_type = "part_of";
      if ($child_gff_obj->get_Annotations('parental_relationship')) {
        foreach my $parental_relationship ($child_gff_obj->get_Annotations('parental_relationship')) {
          my ($term, $parent) = split /\//, $parental_relationship->value();
          if ($parent eq $gff_obj_id) {
            $relationship_type = $term;
            last;
          }
        }
      }

      my $feature_relationship = new ModENCODE::Chado::FeatureRelationship({
          'rank' => 0,
          'type' => new ModENCODE::Chado::CVTerm({
              'name' => $relationship_type,
              'cv' => new ModENCODE::Chado::CV({ 'name' => 'SO' }),
            }),
          'subject' => $child_feature,
          'object' => $feature,
        });

      $child_feature->add_relationship($feature_relationship);
      $feature->add_relationship($feature_relationship);

    }
  }

  if (
    (defined($gff_obj_id) && $gff_obj_id eq $this_seq_region->seq_id()) 
    ||
    $gff_obj->type()->name() eq $this_seq_region->type()->name()
  ) {
    # Don't return the seq_region features
    return undef;
  } else {
    return $feature;
  }
}

sub merge {
  my ($self, $datum, $applied_protocol) = @_;
  return $self->get_datum($datum, $applied_protocol)->{'merged_datum'};
}

1;
