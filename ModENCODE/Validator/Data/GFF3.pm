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
use ModENCODE::Config;
use ModENCODE::ErrorHandler qw(log_error);
use ModENCODE::Parser::GFF3;

my %cached_gff_files            :ATTR( :default<{}> );
my %features_by_uniquename      :ATTR( :default<{}> );
my %seen_data                   :ATTR( :default<{}> );       

sub validate {
  my ($self) = @_;
  my $success = 1;

  log_error "Validating attached GFF3 file(s).", "notice", ">";

  while (my $ap_datum = $self->next_datum) {
    my ($applied_protocol, $direction, $datum) = @$ap_datum;
    next if $seen_data{$datum->get_id}++; # Don't re-update the same datum
    
    my $datum_obj = $datum->get_object;

    if (!length($datum_obj->get_value())) {
      log_error "No GFF3 file for " . $datum_obj->get_heading(), 'warning';
      next;
    } elsif (!-r $datum_obj->get_value()) {
      log_error "Cannot find GFF3 file " . $datum_obj->get_value() . " for column " . $datum_obj->get_heading() . " [" . $datum_obj->get_name . "].", "error";
      $success = 0;
      next;
    } elsif ($cached_gff_files{ident $self}->{$datum_obj->get_value()}++) {
      log_error "Referring to the same GFF3 file (" . $datum_obj->get_value . ") in two different data columns!", "error";
      $success = 0;
      next;
    }

    log_error "Parsing GFF3 file: " . $datum_obj->get_value . ".", "notice", ">";
    # Read the file
    unless (open(GFF, $datum_obj->get_value)) {
      log_error "Couldn't open GFF file " . $datum_obj->get_value . " for reading.", "error";
      $success = 0;
      next;
    }

    # Get genome builds
    my $config = ModENCODE::Config::get_cfg();
    my @build_config_strings = $config->GroupMembers('genome_build');
    my $build_config = {};
    foreach my $build_config_string (@build_config_strings) {
      my (undef, $source, $build) = split(/ +/, $build_config_string);
      $build_config->{$source} = {} unless $build_config->{$source};
      $build_config->{$source}->{$build} = {} unless $build_config->{$source}->{$build};
      my @chromosomes = split(/, */, $config->val($build_config_string, 'chromosomes'));
      my $type = $config->val($build_config_string, 'type');
      foreach my $chr (@chromosomes) {
        $build_config->{$source}->{$build}->{$chr}->{'seq_id'} = $chr;
        $build_config->{$source}->{$build}->{$chr}->{'type'} = $type;
        $build_config->{$source}->{$build}->{$chr}->{'start'} = $config->val($build_config_string, $chr . '_start');
        $build_config->{$source}->{$build}->{$chr}->{'end'} = $config->val($build_config_string, $chr . '_end');
        $build_config->{$source}->{$build}->{$chr}->{'organism'} = $config->val($build_config_string, 'organism');
      }
    }

    my $gff_submission_name = ModENCODE::Config::get_submission_pipeline_name;
    $gff_submission_name =~ s/[^0-9A-Za-z]/_/g;

    my $parser = new ModENCODE::Parser::GFF3({
        'gff3' => \*GFF,
        'builds' => $build_config,
        'id_callback' => *id_callback,
        'source_prefix' => $gff_submission_name,
      });
    $parser->{'gff_submission_name'} = $gff_submission_name;

    my $group_iter = $parser->iterator();
    my $group_num = 0;
    while ($group_iter->has_next()) {
      log_error "Processing GFF feature group #$group_num.", "notice", ">";
      $group_num++;
      my @features;
      eval { @features = $group_iter->next() };
      if ($@) {
        my $errmsg = $@;
        chomp $errmsg;
        my ($message, $line) = ($errmsg =~ m/^(.*)\s+at\s+.*GFF3\.pm\s+line\s+\d+\s*.+line\s+(\d+)/);
        if ($message && $line) {
          log_error "Error parsing GFF '" . $datum_obj->get_value . "': $message at line $line of the GFF.", "error", "<";
        } else {
          log_error "Error parsing GFF: '$errmsg'", "error", "<";
        }
        $success = 0;
        last;
      }
      log_error scalar(@features) . " features found.", "notice";
      foreach my $feature (@features) {
        $datum->get_object->add_feature($feature);
      }
      log_error "Done.", "notice", "<";
    }
    
    close GFF;
    log_error "Done.", "notice", "<";
  }

  log_error "Done.", "notice", "<";
  return $success;
}

my $gff_counter = 1;
sub id_callback {
  my ($parser, $id, $name, $seqid, $source, $type, $start, $end, $score, $strand, $phase) = @_;
  $id ||= "gff_" . sprintf("ID%.6d", ++$gff_counter);
  if ($type !~ /^(gene|transcript|mRNA|CDS|EST|chromosome|chromosome_arm)$/) {
    $id = $parser->{'gff_submission_name'} . "." . $id;
  }
  return $id;
}


1;
