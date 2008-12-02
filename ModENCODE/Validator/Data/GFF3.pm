package ModENCODE::Validator::Data::GFF3;
=pod

=head1 NAME

ModENCODE::Validator::Data::GFF3 - Class for validating and updating BIR-TAB
L<Data|ModENCODE::Chado::Data> objects containing GFF3 files (or rather, paths
to GFF3 files) to include the L<Features|ModENCODE::Chado::Feature> described in
the GFF3 files.

=head1 SYNOPSIS

This class is meant to be used to parse GFF3 files into
L<ModENCODE::Chado::Feature> objects and associated objects, including
L<CVTerms|ModENCODE::Chado::CVTerm>, L<DBXref|ModENCODE::Chado::DBXref>s,
L<FeatureRelationships|ModENCODE::Chado::FeatureRelationship>,
L<FeatureLocs|ModENCODE::Chado::FeatureLoc>,
L<AnalysisFeatures|ModENCODE::Chado::AnalysisFeature>, and
L<Analysis|ModENCODE::Chado::Analysis> objects.  

=head1 USAGE

When given L<ModENCODE::Chado::Data> objects with values that are paths to GFF3
files, the GFF3 file is parsed using a slightly modified version of the
L<Bio::FeatureIO::gff> parser, called L<Bio::FeatureIO::gff_modencode>.
Relationships between features are recorded in the standard GFF3 C<Parent> tag,
with additional support for a C<parental_relationship> attribute that gives the
relationship type, e.g.:

 ChrX  Analysis  gene            1   99  .  +  .  ID=AGene;Name=AGene
 ChrX  Analysis  transcript      1   95  .  +  .  Parent=AGene;parental_relationship=part_of/AGene

The above will be converted into L<ModENCODE::Chado|index> features akin to:

  my $gene = new ModENCODE::Chado::Feature({
    'uniquename' => 'Analysis_AGene',
    'name' => 'AGene',
    'type' => new ModENCODE::Chado::CVTerm({ 
      'name' => 'gene',
      'cv' => new ModENCODE::Chado::CV({ 'name' => 'SO' })
    }),
    'locations' => [
      new ModENCODE::Chado::FeatureLoc({
        'fmin' => 1,
        'fmax' => 99,
        'srcfeature' => new ModENCODE::Chado::Feature({ 'name' => 'ChrX' })
      })
    ]
  });
  my $transcript = new ModENCODE::Chado::Feature({
    'uniquename' => 'gff_obj_transcript/1,95;strand=+;on_chr=ChrX',
    'name' => 'transcript',
    'type' => new ModENCODE::Chado::CVTerm({ 
      'name' => 'transcript',
      'cv' => new ModENCODE::Chado::CV({ 'name' => 'SO' })
    }),
    'locations' => [
      new ModENCODE::Chado::FeatureLoc({
        'fmin' => 1,
        'fmax' => 95,
        'srcfeature' => new ModENCODE::Chado::Feature({ 'name' => 'ChrX' })
      })
    ]
  });
  my $relationship = new ModENCODE::Chado::FeatureRelationship({
    'rank' => 0,
    'type' => new ModENCODE::Chado::CVTerm({
      'name' => 'part_of',
      'cv' => new ModENCODE::Chado::CV({ 'name' => 'SO' })
    })
    'subject' => $transcript,
    'object' => $gene
  });

Although they aren't required, there is also support for typing GFF3 sequence
regions and assigning them to an organism:

 ##sequence-region ChrX 1 99
 ##organism ChrX Drosophila melanogaster
 ChrX  .         chromosome_arm  1   99  .  .  .  ID=2L

Although this syntax is allowed within the GFF3 specification, using the
C<##organism> directive will cause the ordinary L<Bio::FeatureIO::gff3> parser
to show an error that the directive isn't understood - I think the correct
behavior is just to ignore it.

The GFF3 C<Target> attribute can be used to create L<analysis
features|ModENCODE::Chado::AnalysisFeature> for things like BLAST hits or EST
alignments.

 ChrX  BLAST  match       50  70  .    +  . ID=hit_001;Target=AnEST 1 20
 ChrX  BLAST  match_part  50  60  0.9  +  . Parent=hit_001;Target=AnEST 1 10
 ChrX  BLAST  match_part  61  70  0.8  +  . Parent=hit_001;Target=AnEST 11 20

The match line above will be converted into L<ModENCODE::Chado|index> features
akin to:

  my $target = new ModENCODE::Chado::Feature({ 'name' => 'AnEST'  });
  my $analysisfeature_target = new ModENCODE::Chado::AnalysisFeature({
    'feature' => $target,
    'analysis' => new ModENCODE::Chado::Analysis({ 'name' => 'BLAST', 'program' => 'BLAST' }),
  });
  $target->add_analysisfeature($analysisfeature_target);
    
  my $match = new ModENCODE::Chado::Feature({
    'is_analysis' => 1,
    'uniquename' => 'gff_obj_transcript/1,95;strand=+;on_chr=ChrX;hit_from_AnEST(1,20)_by_analysis_BLAST',
    'name' => 'hit_001',
    'type' => new ModENCODE::Chado::CVTerm({
      'name' => 'match',
      'cv' => new ModENCODE::Chado::CV({ 'name' => 'SO' })
    }),
    'locations' => [
      new ModENCODE::Chado::FeatureLoc({
        'rank' => 1,
        'srcfeature' => $target,
        'fmin' => 1,
        'fmax' => 20
      }),
      new ModENCODE::Chado::FeatureLoc({
        'rank' => 0,
        'srcfeature' => new ModENCODE::Chado::Feature({ 'name' => 'ChrX' }),
        'fmin' => 50,
        'fmax' => 70
      })
    ]
  });
  my $analysisfeature_match = new ModENCODE::Chado::AnalysisFeature({
    'feature' => $match,
    'analysis' => new ModENCODE::Chado::Analysis({ 'name' => 'BLAST', 'program' => 'BLAST' }),
  });
  $match->add_analysisfeature($analysisfeature_match);

Note that the C<$target> feature is very simple (and not even a valid Chado
database feature) and is expected to be replaced by a feature from another
validator (like the L<ModENCODE::Validator::Data::dbEST_acc> validator).

L<Data|ModENCODE::Chado::Data> are passed in using L<add_datum($datum,
$applied_protocol)|ModENCODE::Validator::Data::Data/add_datum($datum,
$applied_protocol)>, and then the paths in the data's values are validated and
parsed as GFF3 files.

To use this validator in a standalone way:

  my $attribute = new ModENCODE::Chado::Attribute({
    'value' => '/path/to/gff.gff'
  });
  my $validator = new ModENCODE::Validator::Data::GFF3();
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
$applied_protocol)> have values that point to existing files that can be parsed
as valid GFF3 files.

=item merge($datum, $applied_protocol)

Given an original L<datum|ModENCODE::Chado::Data> C<$datum>,
returns a copy of that datum with a newly attached set of features based on the
GFF3 file pointed to by that C<$datum>.

=back

=head1 TODO

=over

=begin html

<ul>
  <li>Implement support for the C<Gap> attribute</li>
  <li>Make prewritten features optional.</li>
</ul>

=end html

=begin roff

=item Implement support for the C<Gap> attribute

=item Make prewritten features optional.

=end roff

=back

=head1 SEE ALSO

L<ModENCODE::Chado::Data>, L<ModENCODE::Validator::Data>,
L<ModENCODE::Validator::Data::Data>, L<ModENCODE::Chado::Feature>,
L<ModENCODE::Chado::CVTerm>, L<ModENCODE::Chado::CV>,
L<ModENCODE::Chado::Organism>, L<ModENCODE::Chado::AnalysisFeature>,
L<ModENCODE::Chado::Analysis>, L<ModENCODE::Chado::FeatureRelationship>,
L<ModENCODE::Chado::FeatureLoc>, L<ModENCODE::Validator::Data::BED>,
L<ModENCODE::Validator::Data::Result_File>,
L<ModENCODE::Validator::Data::SO_transcript>,
L<ModENCODE::Validator::Data::WIG>, L<ModENCODE::Validator::Data::dbEST_acc>,
L<ModENCODE::Validator::Data::dbEST_acc_list>,

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use base qw( ModENCODE::Validator::Data::Data );
use Class::Std;
use Data::Dumper;
use Carp qw(croak carp);
use SOAP::Lite;
use Bio::FeatureIO::gff_modencode;
use ModENCODE::Config;
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

      my @build_config_strings = ModENCODE::Config::get_cfg()->GroupMembers('genome_build');
      my $build_config = {};
      foreach my $build_config_string (@build_config_strings) {
        my (undef, $source, $build) = split / +/, $build_config_string, 3;
        $build_config->{$source} = {} unless $build_config->{$source};
        $build_config->{$source}->{$build} = [] unless $build_config->{$source}->{$build};
        my @chromosomes = split /, */, ModENCODE::Config::get_cfg()->val($build_config_string, 'chromosomes');
        my $region_type = ModENCODE::Config::get_cfg()->val($build_config_string, 'region_type');
        foreach my $chr (@chromosomes) {
          push @{$build_config->{$source}->{$build}}, { 
            'seq_id' => $chr, 
            'region_type' => $region_type,
            'start' => ModENCODE::Config::get_cfg()->val($build_config_string, $chr . '_start'),
            'end' => ModENCODE::Config::get_cfg()->val($build_config_string, $chr . '_end'),
            'organism' => ModENCODE::Config::get_cfg()->val($build_config_string, 'organism'),
          };
        }
      }

      my $gffio = new Bio::FeatureIO(-fh => \*GFF, -format => 'gff_modencode', -version => 3, -build_config => $build_config);
      while (my @group_features = $gffio->next_feature_group()) {
        foreach my $top_level_feature (@group_features) {
          # These all get cached in features_by_id and features_by_uniquename
          my $feature = $self->gff_feature_to_chado_features($gffio, $top_level_feature, $analysis, \%features_by_id);
          if ($feature == -1) {
            $success = 0;
            next;
          }
          if ($feature) {
            $datum->add_feature($feature);
          }
        }
      }
      $cached_gff_features{ident $self}->{$gff_file} = \%features_by_id;
      close GFF;
      log_error "Done.", "notice", "<";
    } else {
      foreach my $feature (values(%{$cached_gff_features{ident $self}->{$gff_file}})) {
        $datum->add_feature($feature);
      }
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

  # Get the sequence region feature, or create one if it doesn't yet exist
  my $this_seq_region = $gff_io->sequence_region($gff_obj->seq_id());
  if (!$this_seq_region) {
    log_error "Cannot find a sequence region defined by ##sequence-region or ##genome-build header for " . $gff_obj->seq_id() . ".", "error";
    return -1;
  }
  my $this_seq_region_feature = $features_by_id->{$this_seq_region->seq_id()};
  if (!$this_seq_region_feature) {
    $this_seq_region_feature = new ModENCODE::Chado::Feature({
        'uniquename' => $this_seq_region->seq_id(),
        'name' => $this_seq_region->seq_id(),
        'type' => new ModENCODE::Chado::CVTerm({
            'name' => $this_seq_region->type()->name(),
            'cv' => new ModENCODE::Chado::CV({ 
                'name' => 'SO',
              }),
          }),
      });
    if ($gff_obj_id eq $this_seq_region->seq_id()) {
      $this_seq_region_feature->set_uniquename($this_seq_region_feature->get_uniquename . "_" . $this_seq_region->type()->name() . "/" . $this_seq_region->start() . "," . $this_seq_region->end() . "_region")
    }
    my $genus = ($this_seq_region->get_Annotations('Organism_Genus'))[0];
    my $species = ($this_seq_region->get_Annotations('Organism_Species'))[0];
    $genus = $genus->value() if ref($genus);
    $species = $species->value() if ref($species);

    my $organism = new ModENCODE::Chado::Organism({
        'genus' => ($genus || "Unknown"),
        'species' => ($species || "organism"),
      });
    $this_seq_region_feature->set_organism($organism);
    $features_by_id->{$this_seq_region->seq_id()} = $this_seq_region_feature;
  }

  # Deal with typing the sequence region
  if ($gff_obj_id eq $this_seq_region->seq_id()) {
    # If we have a feature with the same ID as the seqregion, then assign its type to
    # the seqregion, instead of relying on the default "region"
      if (!($this_seq_region_feature->get_type())) {
	  log_error "You have an error with your GFF file at the feature " . $this_seq_region_feature->to_string() . "\n  You might not have your features in the correct order.  Be sure your Parent features occur first, followed by Target features, followed by the rest.", "error";
	  return -1;
      } else {
	  $this_seq_region_feature->get_type()->set_name($gff_obj->type()->name());
      }
    # Return this as the feature
    return $this_seq_region_feature;
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

  my $uniquename = $gff_obj->source() . "_" . $gff_id . ":gff_obj_" . $gff_obj->type()->name() . "/$feature_start,$feature_end";
  $uniquename .= ";strand=" . $gff_obj->strand() if defined($gff_obj->strand());
  $uniquename .= ";score=" . $gff_obj->score() if defined($gff_obj->score());
  $uniquename .= ";phase=" . $gff_obj->phase() if defined($gff_obj->phase());
  $uniquename .= ";on_chr=" . $gff_obj->seq_id();

  my $feature = $features_by_uniquename{ident $self}->{$uniquename};
  if (!$feature) {

    my $genus = ($this_seq_region->get_Annotations('Organism_Genus'))[0];
    my $species = ($this_seq_region->get_Annotations('Organism_Species'))[0];
    $genus = $genus->value() if ref($genus);
    $species = $species->value() if ref($species);

    my $organism = new ModENCODE::Chado::Organism({
        'genus' => ($genus || 'Unknown'),
        'species' => ($species || 'organism'),
      });

    my $type = new ModENCODE::Chado::CVTerm({
        'name' => $gff_obj->type()->name(),
        'cv' => new ModENCODE::Chado::CV({ 'name' => 'SO' }),
      });

    my $primary_location;
   
    if (defined($feature_start) || defined($feature_end)) {
      $primary_location = new ModENCODE::Chado::FeatureLoc({ # vs. chromosome
          'rank' => 0,
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
            'uniquename' => $target_name . "_to_be_loaded",
          });
        my $analysisfeature = new ModENCODE::Chado::AnalysisFeature({
            'feature' => $target_feature,
            'analysis' => $analysis,
          });
        if ($gff_obj->score()) {
          my $rawscore = ref($gff_obj->score) ? $gff_obj->score()->value() : $gff_obj->score();
          $rawscore = undef if ($rawscore eq '.' || $rawscore eq '');
          $analysisfeature->set_rawscore($rawscore);
        }
        $target_feature->add_analysisfeature($analysisfeature);
        $features_by_id->{$target_name} = $target_feature;
      }
      $target_location = new ModENCODE::Chado::FeatureLoc({ # vs. target/est
          'rank' => 1,
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
	my $rawscore = ref($gff_obj->score) ? $gff_obj->score()->value() : $gff_obj->score();
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
