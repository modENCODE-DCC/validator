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

my %cached_gff_features         :ATTR( :default<{}> );
my %features_by_uniquename      :ATTR( :default<{}> );

sub validate {
  my ($self) = @_;
  log_error "Parsing attached GFF3 files.", "notice", ">";
  my $success = 1;

#  my @gff_files;
  foreach my $datum_hash (@{$self->get_data()}) {
    my $datum = $datum_hash->{'datum'}->clone();
    my $applied_protocol = $datum_hash->{'applied_protocol'}->clone();
    my $gff_file = $datum->get_value();
    next unless length($gff_file);
    log_error "Parsing GFF file " . $gff_file . ".", "notice", ">";
    if (!-r $gff_file) {
      log_error "Cannot read GFF file '$gff_file'.";
      $success = 0;
      next;
    }
    if (!$cached_gff_features{ident $self}->{$gff_file}) {
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
      my %features_by_id;
      my $gffio = new Bio::FeatureIO(-fh => \*GFF, -format => 'gff_modencode', -version => 3);
      while (my @group_features = $gffio->next_feature_group()) {
        foreach my $top_level_feature (@group_features) {
          # These all get cached in features_by_id and features_by_uniquename
          log_error "Sorting out a feature into a chado feature: " . ($top_level_feature->get_Annotations('ID'))[0], "notice", ">";
          my $feature = $self->gff_feature_to_chado_features($gffio, $top_level_feature, $analysis, \%features_by_id);
          if ($feature) {
            $datum->add_feature($feature);
          }
          log_error "Done.", "notice", "<";
        }
      }
      $cached_gff_features{ident $self}->{$gff_file} = \%features_by_id;
      close GFF;
    }

    log_error "Done.", "notice", "<";
    $datum_hash->{'merged_datum'} = $datum;
  }
  log_error "Done.", "notice", "<";
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

  # Deal with typing the sequence region
  if ($gff_obj->seq_id() eq $gff_io->sequence_region($gff_obj->seq_id()) && 
    defined($gff_obj->get_Annotations('ID')) && defined(($gff_obj->get_Annotations('ID'))[0]) && 
    ($gff_obj->get_Annotations('ID'))[0]->value() eq $gff_io->seq_region($gff_obj->seq_id())->seq_id() &&
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
  my $name = $gff_obj->name() || ($gff_obj->get_Annotations('ID'))[0] || "gff_obj_" . $gff_obj->type()->name() . "/$feature_start,$feature_end";

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

    my $primary_location = new ModENCODE::Chado::FeatureLoc({ # vs. chromosome
        'rank' => 1,
        'srcfeature' => $this_seq_region_feature,
        'fmin' => $feature_start,
        'fmax' => $feature_end,
        'strand' => ($gff_obj->strand() eq '-' ? -1 : 1),
        'phase' => ($gff_obj->phase() eq '.' ? 0 : $gff_obj->phase()),
      });


    ##########################################
    # TODO: If the Target attribute is used, create a placeholder feature for it
    my $target_location;
    my ($target) = $gff_obj->annotation()->get_Annotations("Target");
    if ($target) {
      # This will later be replaced with:
      #  a link to a feature from the SDRF (TODO first)
      #  a link to a feature in the final structure (TODO)
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
        $analysisfeature->set_rawscore($gff_obj->score()->value()) if $gff_obj->score();
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
        'locations' => [ $primary_location ],
      });
    $features_by_uniquename{ident $self}->{$uniquename} = $feature;
    if (($gff_obj->get_Annotations('ID'))[0]) {
      $features_by_id->{($gff_obj->get_Annotations('ID'))[0]} = $feature;
    }
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
      $analysisfeature->set_rawscore($gff_obj->score()->value()) if $gff_obj->score();
      $feature->add_analysisfeature($analysisfeature);
    }
  }
  
  my @child_gff_features = $gff_obj->get_SeqFeatures();
  if (scalar(@child_gff_features)) {
    # Has children
    my $rank = 0;
    foreach my $child_gff_obj ($gff_obj->get_SeqFeatures()) {
      my $child_feature = $self->gff_feature_to_chado_features($gff_io, $child_gff_obj, $analysis, $features_by_id);
      my $relationship_type = "part_of";
      if ($child_gff_obj->get_Annotations('parental_relationship')) {
        foreach my $parental_relationship ($child_gff_obj->get_Annotations('parental_relationship')) {
          my ($term, $parent) = split /\//, $parental_relationship->value();
          if ($parent eq ($gff_obj->get_Annotations('ID'))[0]->value()) {
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
    (($gff_obj->get_Annotations('ID'))[0] && ($gff_obj->get_Annotations('ID'))[0] eq $this_seq_region->seq_id()) 
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
