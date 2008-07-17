package ModENCODE::Validator::Data::SO_transcript;
=pod

=head1 NAME

ModENCODE::Validator::Data::SO_transcript - Class for validating and updating
BIR-TAB L<Data|ModENCODE::Chado::Data> objects containing transcript names to
include L<Features|ModENCODE::Chado::Feature> for those transcripts.

=head1 SYNOPSIS

This class is meant to be used to build a L<ModENCODE::Chado::Feature> object
(and associated L<CVTerms|ModENCODE::Chado::CVTerm>,
L<FeatureLocs|ModENCODE::Chado::FeatureLoc>,
L<Organisms|ModENCODE::Chado::Organism>, and
L<DBXrefs|ModENCODE::Chado::DBXref> for a provided transcript name (as
kept in the C<feature.name> field of a Chado database. Transcript information
will be fetched from either the local modENCODE Chado database defined in the
C<[databases modencode]> section of the ini-file loaded by
L<ModENCODE::Config>), or if not found there, then from the FlyBase database
defined in the C<[databases flybase]> section of the ini-file.

=head1 USAGE

When given L<ModENCODE::Chado::Data> objects with values that are transcript
names, this modules uses
L<ModENCODE::Parser::Chado/get_feature_id_by_name_and_type($name, $type,
$allow_isa)> to pull out C<feature_id>s for features of type C<SO:transcript> or
children of the C<SO:transcript> type like C<SO:mRNA>. (This is achieved by
passing in a value of 1 for C<$allow_isa>.) The C<feature_id>s are then used to
pull out full L<Feature|ModENCODE::Chado::Feature> objects using
L<ModENCODE::Parser::Chado/get_feature($feature_id)>, which can include other
attached features (genes, exons, etc.) as well as L<ModENCODE::Chado::CVTerm>s,
L<ModENCODE::Chado::DBXref>s, and so forth. The originally requested feature is
then added to the original datum (and by association, so are the other connected
objects).
 
To use this validator in a standalone way:

  my $datum = new ModENCODE::Chado::Data({
    'value' => 'TranscriptName'
  });
  my $validator = new ModENCODE::Validator::Data::SO_transcript();
  $validator->add_datum($datum, $applied_protocol);
  if ($validator->validate()) {
    my $new_datum = $validator->merge($datum);
    print $new_datum->get_features()->[0]->get_name();
  }

Note that this class is not meant to be used directly, rather it is mean to be
used within L<ModENCODE::Validator::Data>.

=head1 FUNCTIONS

=over

=item validate()

Makes sure that all of the data added using L<add_datum($datum,
$applied_protocol)|ModENCODE::Validator::Data::Data/add_datum($datum,
$applied_protocol)> have values that exist as transcript names accession in the
C<feature.name> column of either the local modENCODE database or FlyBase.

=item merge($datum, $applied_protocol)

Given an original L<datum|ModENCODE::Chado::Data> C<$datum>, returns a copy of
that datum with a newly attached feature based on a transcript record and other
attached features in either the local modENCODE database or FlyBase for the
value in that C<$datum>.

B<NOTE:> In addition to attaching features to the current C<$datum>, if there is
a GFF3 datum (as validated by L<ModENCODE::Validator::Data::GFF3>) attached to
the same C<$applied_protocol>, then the features within it are scanned for any
with the name equal to the transcript name - if these are found, they are
replaced (using L<ModENCODE::Chado::Feature/mimic($feature)>).

=back

=head1 SEE ALSO

L<ModENCODE::Chado::Data>, L<ModENCODE::Validator::Data>,
L<ModENCODE::Validator::Data::Data>, L<ModENCODE::Chado::Feature>,
L<ModENCODE::Chado::CVTerm>, L<ModENCODE::Chado::Organism>,
L<ModENCODE::Chado::FeatureLoc>, L<ModENCODE::Validator::Data::BED>,
L<ModENCODE::Validator::Data::Result_File>,
L<ModENCODE::Validator::Data::dbEST_acc>,
L<ModENCODE::Validator::Data::WIG>, L<ModENCODE::Validator::Data::GFF3>,
L<ModENCODE::Validator::Data::dbEST_acc_list>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use base qw( ModENCODE::Validator::Data::Data );
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::Parser::Chado;
use ModENCODE::ErrorHandler qw(log_error);
use ModENCODE::Chado::Feature;
use ModENCODE::Chado::CVTerm;
use ModENCODE::Chado::CV;
use ModENCODE::Chado::Organism;
use ModENCODE::Chado::FeatureLoc;
use ModENCODE::Config;

my %cached_features              :ATTR( :default<{}> );
my %modencode_parser             :ATTR( :default<undef> );
my %flybase_parser               :ATTR( :default<undef> );

sub validate {
  my ($self) = @_;
  log_error "Loading transcripts from database.", "notice", ">";
  my $success = 1;

  my @ids;
  my $i = 0;
  foreach my $datum_hash (@{$self->get_data()}) {
    $i++;
    if (length($datum_hash->{'datum'}->get_value())) {
      my $feature = $cached_features{ident $self}->{$datum_hash->{'datum'}->get_value()};
      next if (!$feature && defined($feature));
      if (!$feature && !defined($feature)) {
        log_error "Fetching feature " . $datum_hash->{'datum'}->get_value() . ", $i of " . scalar(@{$self->get_data()}) . ".", "notice";
        my $feature_id = $self->get_parser_modencode()->get_feature_id_by_name_and_type(
          $datum_hash->{'datum'}->get_value(),
          new ModENCODE::Chado::CVTerm({
              'name' => 'transcript',
              'cv' => new ModENCODE::Chado::CV({ 'name' => 'SO' }),
            }),
          1,
        );
        if ($feature_id) {
          $feature = $self->get_parser_modencode()->get_feature($feature_id);
        }
      }
      if (!$feature && !defined($feature)) {
        my $feature_id = $self->get_parser_flybase()->get_feature_id_by_name_and_type(
          $datum_hash->{'datum'}->get_value(),
          new ModENCODE::Chado::CVTerm({
              'name' => 'transcript',
              'cv' => new ModENCODE::Chado::CV({ 'name' => 'SO' }),
            }),
          1,
        );
        if ($feature_id) {
          $feature = $self->get_parser_flybase()->get_feature($feature_id);
        }
      }
      if (!$feature && !defined($feature)) {
        log_error "Couldn't get a feature object for supposed transcript " . $datum_hash->{'datum'}->get_value() . ".", "error";
        $success = 0;
        $cached_features{ident $self}->{$datum_hash->{'datum'}->get_value()} = 0;
        next;
      } elsif ($feature) {
        $cached_features{ident $self}->{$datum_hash->{'datum'}->get_value()} = $feature;
      }
      my $datum = $datum_hash->{'datum'}->clone();
      $datum->add_feature($feature);
      $datum_hash->{'merged_datum'} = $datum;
    }
  }

  log_error "Done.", "notice", "<";
  return $success;
}

sub merge {
  my ($self, $datum, $applied_protocol) = @_;
  my $validated_datum = $self->get_datum($datum, $applied_protocol)->{'merged_datum'};


  # If there's a GFF attached to this particular protocol, update any entries referencing this transcript
  if ($validated_datum && scalar(@{$validated_datum->get_features()})) {
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
  if (!$flybase_parser{ident $self}) {
    $flybase_parser{ident $self} = new ModENCODE::Parser::Chado({
        'dbname' => ModENCODE::Config::get_cfg()->val('databases flybase', 'dbname'),
        'host' => ModENCODE::Config::get_cfg()->val('databases flybase', 'host'),
        'port' => ModENCODE::Config::get_cfg()->val('databases flybase', 'port'),
        'username' => ModENCODE::Config::get_cfg()->val('databases flybase', 'username'),
        'password' => ModENCODE::Config::get_cfg()->val('databases flybase', 'password'),
        'no_relationships' => 1,
      });
  }
  return $flybase_parser{ident $self};
}

sub get_parser_modencode : PRIVATE {
  my ($self) = @_;
  if (!$modencode_parser{ident $self}) {
    $modencode_parser{ident $self} = new ModENCODE::Parser::Chado({
        'dbname' => ModENCODE::Config::get_cfg()->val('databases modencode', 'dbname'),
        'host' => ModENCODE::Config::get_cfg()->val('databases modencode', 'host'),
        'port' => ModENCODE::Config::get_cfg()->val('databases modencode', 'port'),
        'username' => ModENCODE::Config::get_cfg()->val('databases modencode', 'username'),
        'password' => ModENCODE::Config::get_cfg()->val('databases modencode', 'password'),
        'no_relationships' => 1,
      });
  }
  return $modencode_parser{ident $self};
}

1;
